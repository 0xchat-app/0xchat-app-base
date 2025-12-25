import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'base64.dart';
import 'package:http_parser/src/media_type.dart';
import 'uploader.dart';

class FileDropUploader {
  // Chunked upload configuration
  static const int _chunkSize = 256 * 1024; // 256KB per chunk
  static const int _maxParallelChunks = 3; // Upload 3 chunks concurrently
  static const int _maxChunkRetries = 3;
  static const Duration _chunkTimeout = Duration(seconds: 60);
  
  // Configure Dio for single file uploads
  static Dio _createDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        // Extended timeouts for large files (10 minutes)
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 10),
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }
  
  // Configure Dio for chunked uploads with stricter timeouts
  static Dio _createChunkDio() {
    return Dio(
      BaseOptions(
        connectTimeout: _chunkTimeout,
        sendTimeout: _chunkTimeout,
        receiveTimeout: _chunkTimeout,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }
  
  /// Generate unique upload ID for chunked uploads
  static String _generateUploadId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    final randomStr = List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
    return '${DateTime.now().millisecondsSinceEpoch}-$randomStr';
  }

  /// Upload file to FileDrop server with automatic chunking for large files
  /// [serverUrl] The base URL of the FileDrop server (e.g., https://filedrop.besoeasy.com/)
  /// [filePath] Local file path to upload
  /// [fileName] Optional file name
  /// [onProgress] Optional progress callback (0.0 to 1.0)
  /// [maxRetries] Maximum number of retry attempts for single uploads (default: 3)
  static Future<String?> upload(
    String serverUrl,
    String filePath, {
    String? fileName,
    Function(double progress)? onProgress,
    int maxRetries = 3,
  }) async {
    // Ensure serverUrl ends with /
    if (!serverUrl.endsWith('/')) {
      serverUrl = '$serverUrl/';
    }
    
    // Check if this is a base64 encoded string or file path
    if (BASE64.check(filePath)) {
      // Base64 data - use single upload
      return await _uploadSingle(
        serverUrl,
        filePath,
        fileName: fileName,
        onProgress: onProgress,
        maxRetries: maxRetries,
      );
    }
    
    // File path - check size to determine upload strategy
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }
    
    final fileSize = await file.length();
    
    // Use chunked upload for files >= 256KB
    if (fileSize >= _chunkSize) {
      return await _uploadChunked(
        serverUrl,
        file,
        fileName: fileName,
        onProgress: onProgress,
      );
    } else {
      // Small file - use single upload
      return await _uploadSingle(
        serverUrl,
        filePath,
        fileName: fileName,
        onProgress: onProgress,
        maxRetries: maxRetries,
      );
    }
  }
  
  /// Upload small files in a single request with retry logic
  static Future<String?> _uploadSingle(
    String serverUrl,
    String filePath, {
    String? fileName,
    Function(double progress)? onProgress,
    int maxRetries = 3,
  }) async {
    final uploadUrl = '${serverUrl}upload';
    
    // Retry logic for handling network interruptions
    int attempts = 0;
    Exception? lastError;
    
    while (attempts < maxRetries) {
      attempts++;
      
      try {
        final dio = _createDio();
        var fileType = Uploader.getFileType(filePath);
        MultipartFile? multipartFile;
        
        if (BASE64.check(filePath)) {
          var bytes = BASE64.toData(filePath);
          multipartFile = await MultipartFile.fromBytes(
            bytes,
            filename: fileName,
            contentType: MediaType.parse(fileType),
          );
        } else {
          multipartFile = await MultipartFile.fromFile(
            filePath,
            filename: fileName,
            contentType: MediaType.parse(fileType),
          );
        }

        var formData = FormData.fromMap({'file': multipartFile});
        
        var response = await dio.post(
          uploadUrl,
          data: formData,
          onSendProgress: (count, total) {
            // Adjust progress to account for retries
            final baseProgress = (attempts - 1) / maxRetries;
            final currentProgress = (count / total) / maxRetries;
            onProgress?.call(baseProgress + currentProgress);
          },
        );
        
          var body = response.data;
        
        // Handle different response formats
        if (body is Map<String, dynamic>) {
          // Extract MIME type from response if available
          String? mimeType;
          if (body.containsKey('mime_type')) {
            mimeType = body['mime_type'] as String?;
          } else if (body.containsKey('details') && body['details'] is Map) {
            final details = body['details'] as Map;
            if (details.containsKey('mime_type')) {
              mimeType = details['mime_type'] as String?;
            }
          }
          
          // Try common response field names
          String? url;
          if (body.containsKey('url')) {
            url = body['url'] as String?;
          } else if (body.containsKey('fileUrl')) {
            url = body['fileUrl'] as String?;
          } else if (body.containsKey('data') && body['data'] is Map) {
            final data = body['data'] as Map;
            if (data.containsKey('url')) {
              url = data['url'] as String?;
            }
          } else {
            // If response is a map but no URL found, return the first string value or null
            for (var value in body.values) {
              if (value is String && (value.startsWith('http://') || value.startsWith('https://'))) {
                url = value;
                break;
              }
            }
          }
          
          // Add MIME type to URL if available
          if (url != null && mimeType != null) {
            try {
              final uri = Uri.parse(url);
              final updatedUri = uri.replace(
                queryParameters: {
                  ...uri.queryParameters,
                  'm': mimeType, // Add MIME type as query parameter for message type identification
                },
              );
              return updatedUri.toString();
            } catch (e) {
              return url;
            }
          }
          
          if (url != null) {
            return url;
          }
        } else if (body is String) {
          // If response is a direct URL string
          if (body.startsWith('http://') || body.startsWith('https://')) {
            return body;
          }
        }
        
        // If no valid URL found but response was successful, retry might not help
        if (response.statusCode == 200 || response.statusCode == 201) {
          return null;
        }
        
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        
        // Check if error is retryable
        final isRetryable = _isRetryableError(e);
        
        if (!isRetryable || attempts >= maxRetries) {
          // Non-retryable error or max retries reached
          rethrow;
        }
        
        // Wait before retrying with exponential backoff
        if (attempts < maxRetries) {
          final delaySeconds = attempts * 2; // 2s, 4s, 6s...
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      }
    }
    
    // All retries exhausted
    if (lastError != null) {
      throw lastError;
    }
    
    return null;
  }
  
  /// Upload large files using chunked upload (256KB chunks)
  static Future<String?> _uploadChunked(
    String serverUrl,
    File file, {
    String? fileName,
    Function(double progress)? onProgress,
  }) async {
    final uploadUrl = '${serverUrl}upload';
    final fileSize = await file.length();
    final totalChunks = (fileSize / _chunkSize).ceil();
    final uploadId = _generateUploadId();
    final actualFileName = fileName ?? file.path.split('/').last;
    
    // Track completed chunks for progress reporting
    int completedChunks = 0;
    String? finalUrl;
    
    // Upload chunks in parallel batches
    for (int batchStart = 0; batchStart < totalChunks; batchStart += _maxParallelChunks) {
      final batchEnd = min(batchStart + _maxParallelChunks, totalChunks);
      final futures = <Future<Response>>[];
      
      // Create batch of parallel chunk uploads
      for (int chunkIndex = batchStart; chunkIndex < batchEnd; chunkIndex++) {
        futures.add(_uploadChunkWithRetry(
          uploadUrl: uploadUrl,
          file: file,
          uploadId: uploadId,
          chunkIndex: chunkIndex,
          totalChunks: totalChunks,
          fileName: actualFileName,
        ));
      }
      
      // Wait for all chunks in this batch to complete
      final responses = await Future.wait(futures);
      
      // Check responses for final result (returned by last chunk)
      for (final response in responses) {
        completedChunks++;
        
        if (response.data is Map<String, dynamic>) {
          final body = response.data as Map<String, dynamic>;
          
          // Check if this is the final response with URL
          if (body.containsKey('url') && body['url'] != null) {
            finalUrl = _extractUrl(body);
          } else if (body.containsKey('cid') && body['cid'] != null) {
            // Build URL from CID if provided
            final cid = body['cid'] as String;
            final filename = body['filename'] ?? actualFileName;
            finalUrl = 'https://dweb.link/ipfs/$cid?filename=$filename';
          }
        }
        
        // Update progress
        if (onProgress != null) {
          final currentProgress = completedChunks / totalChunks;
          onProgress(currentProgress);
        }
      }
    }
    
    return finalUrl;
  }
  
  /// Upload a single chunk with retry logic
  static Future<Response> _uploadChunkWithRetry({
    required String uploadUrl,
    required File file,
    required String uploadId,
    required int chunkIndex,
    required int totalChunks,
    required String fileName,
    int retryCount = 0,
  }) async {
    try {
      final dio = _createChunkDio();
      final fileSize = await file.length();
      final start = chunkIndex * _chunkSize;
      final end = min(start + _chunkSize, fileSize);
      
      // Read chunk data on-demand (streaming, not loading entire file)
      final chunkStream = file.openRead(start, end);
      final chunkBytes = await chunkStream.expand((x) => x).toList();
      
      // Create multipart form data for chunk
      final formData = FormData.fromMap({
        'uploadId': uploadId,
        'chunkIndex': chunkIndex.toString(),
        'totalChunks': totalChunks.toString(),
        'file': MultipartFile.fromBytes(
          chunkBytes,
          filename: fileName,
          contentType: MediaType.parse(Uploader.getFileType(fileName)),
        ),
      });
      
      // Upload chunk using PUT method (as per API docs)
      final response = await dio.put(
        uploadUrl,
        data: formData,
      );
      
      return response;
      
    } catch (e) {
      // Retry logic with exponential backoff
      if (retryCount < _maxChunkRetries && _isRetryableError(e)) {
        final delaySeconds = retryCount + 1; // 1s, 2s, 3s
        await Future.delayed(Duration(seconds: delaySeconds));
        
        return _uploadChunkWithRetry(
          uploadUrl: uploadUrl,
          file: file,
          uploadId: uploadId,
          chunkIndex: chunkIndex,
          totalChunks: totalChunks,
          fileName: fileName,
          retryCount: retryCount + 1,
        );
      }
      
      // Max retries exceeded or non-retryable error
      rethrow;
    }
  }
  
  /// Extract URL from response body
  static String? _extractUrl(Map<String, dynamic> body) {
    // Try common response field names
    if (body.containsKey('url')) {
      return body['url'] as String?;
    } else if (body.containsKey('fileUrl')) {
      return body['fileUrl'] as String?;
    } else if (body.containsKey('data') && body['data'] is Map) {
      final data = body['data'] as Map;
      if (data.containsKey('url')) {
        return data['url'] as String?;
      }
    } else {
      // If response is a map but no URL found, return the first string value
      for (var value in body.values) {
        if (value is String && (value.startsWith('http://') || value.startsWith('https://'))) {
          return value;
        }
      }
    }
    return null;
  }
  
  /// Check if an error is retryable (network issues, timeouts, etc.)
  static bool _isRetryableError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.badResponse:
          // Retry on 5xx server errors
          final statusCode = error.response?.statusCode;
          return statusCode != null && statusCode >= 500;
        default:
          return false;
      }
    }
    
    // Retry on socket exceptions and other network errors
    return error.toString().toLowerCase().contains('socket') ||
           error.toString().toLowerCase().contains('network') ||
           error.toString().toLowerCase().contains('connection');
  }
}

