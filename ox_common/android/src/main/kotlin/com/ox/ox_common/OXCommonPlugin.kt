package com.ox.ox_common

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.text.TextUtils
import android.util.Log
import android.widget.Toast
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import com.ox.ox_common.utils.BitmapUtils
import com.ox.ox_common.utils.Const
import com.ox.ox_common.utils.FileUtils
import com.ox.ox_common.utils.Tools
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import java.io.File

/** OXCommonPlugin */
class OXCommonPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var mContext: Context
    private val TAG: String = "OXCommonPlugin";

    private val CODE_IMAGE_FROM_CAMERRA = 155
    private val CODE_IMAGE_FROM_GALLERY = 156
    private val CODE_CROP_BIG_PICTURE = 157
    private val CODE_VIDEO = 158

    private var mResult: Result? = null
    private var mIsNeedCrop = false
    private var _tempImageFileLocation: String? = null
    private var _mCropImgPath: String? = null
    private var _mFileName: String? = null

    private lateinit var mActivity: Activity

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        mContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ox_common")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (call.hasArgument("isNeedTailor")) {
            mIsNeedCrop = call.argument<Boolean>("isNeedTailor")!!
        }
        mResult = result
        _tempImageFileLocation = null
        when (call.method) {
            "getImageFromCamera" -> takePhoto(mActivity, CODE_IMAGE_FROM_CAMERRA, getTempImageFileUri(".jpg"))
            "getImageFromGallery" -> choosePhoto(mActivity, CODE_IMAGE_FROM_GALLERY)
            "getVideoFromCamera" -> takeVideo(mActivity, CODE_VIDEO, getTempImageFileUri(".mp4"))
            "getCompressionImg" -> {
                var filePath: String? = null
                if (call.hasArgument("filePath")) {
                    filePath = call.argument<String>("filePath")
                }
                var quality = 100
                if (call.hasArgument("quality")) {
                    quality = call.argument<Int>("quality")!!
                }
                if (filePath != null) {
                    getCompressionImg(filePath, quality)
                }
            }
            "saveImageToGallery" -> {
                var imageBytes: ByteArray? = null
                if (call.hasArgument("imageBytes")) {
                    imageBytes = call.argument<ByteArray>("imageBytes")
                }
                var name: String? = null
                if (call.hasArgument("name")) {
                    name = call.argument<String>("name")
                }
                var quality = 100
                if (call.hasArgument("quality")) {
                    quality = call.argument<Int>("quality")!!
                }
                val path: String = BitmapUtils.saveImageToGallery(mActivity, BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes!!.size), false)
                result.success(path);
            }
            "callSysShare" -> {
                var filePath: String? = null
                if (call.hasArgument("filePath")) {
                    filePath = call.argument<String>("filePath")
                }
                if (!TextUtils.isEmpty(filePath))
                    goSysShare(filePath!!);
            }
            "backToDesktop" -> {
                if (mResult != null) {
                    mResult!!.success(true)
                    mActivity.moveTaskToBack(false)
                }
            }
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "getDeviceId" -> result.success(Tools.getAndroidId(mContext))
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onDetachedFromActivity() {
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        mActivity = binding.activity


        binding.addActivityResultListener(ActivityResultListener { requestCode, responseCode, data ->
            if (responseCode != Activity.RESULT_OK) {
                false
            } else {
                if (requestCode == CODE_VIDEO) {
//                        Uri uriVideo = data.getData();
                    val uriVideo = getTempImageFileUri(".mp4")
                    val videoFilePath = FileUtils.uri2File(mActivity, uriVideo)
                    processResult(videoFilePath)
                    return@ActivityResultListener true
                }
                val uri = getTempImageFileUri(".jpg")
                if (uri == null || _tempImageFileLocation == null) {
                    Toast.makeText(mActivity, mActivity.resources.getString(R.string.str_picker_image_sdcar_error), Toast.LENGTH_SHORT).show()
                    return@ActivityResultListener false
                }
                if (requestCode == CODE_IMAGE_FROM_CAMERRA) {
                    if (mIsNeedCrop) {
                        var cropUri = uri
                        val srcUri: Uri = uri
                        if (Build.VERSION.SDK_INT >= 30) {
                            cropUri = getSDK30PictureUri()
                            //                                srcUri = originalPhotoForChoose;
                        }
                        startPhotoCrop(srcUri, cropUri!!, 200, 200, CODE_CROP_BIG_PICTURE)
                    } else {
                        if (data != null) {
                            val extras = data.extras
                            if (extras != null) {
                                val imageBitmap = extras["data"] as Bitmap?
                                if (imageBitmap != null) {
                                    val saveFlag = FileUtils.saveBitmap(imageBitmap, File(_tempImageFileLocation), Bitmap.CompressFormat.JPEG, 100)
                                }
                            }
                        }
                        processResult(_tempImageFileLocation!!)
                    }
                    return@ActivityResultListener true
                } else if (requestCode == CODE_IMAGE_FROM_GALLERY) {
                    if (data == null || data.data == null) return@ActivityResultListener false
                    // URI of the selected photo in the album
                    val originalPhotoForChoose = data.data
                    if (mIsNeedCrop) {
                        // The File corresponding to the original photo's URI
                        val originalPhotoForChooseCopySrc = FileUtils.uri2File(mActivity, originalPhotoForChoose)
                        // Make a copy of the selected original image (for cropping purposes)
                        val originalPhotoForChooseCopyDest = _tempImageFileLocation
                        if (originalPhotoForChooseCopySrc != null) {
                            var copyOK = false
                            try {
                                // Make a copy of the selected original image (for cropping purposes)
                                copyOK = FileUtils.copyFile(originalPhotoForChooseCopySrc, originalPhotoForChooseCopyDest)
                            } catch (e: java.lang.Exception) {
                                Log.e(TAG, e.message, e)
                            }
                            // Copy of the image to be cropped is ready
                            // In practice, it's just copying to the location of the temp file. In the camera, the photo is automatically saved to the temp location after taking the picture
                            if (copyOK) {
                                Log.d(TAG, "【ChangeAvatar】CHOOSE_BIG_PICTURE2: data = " + data //+",uri=="+uri
                                        + ",originalPhotoForChoose=" + originalPhotoForChoose) //it seems to be null

                                // Copy completed, entering cropping process
                                if (originalPhotoForChoose != null) {
                                    var cropUri = uri
                                    var srcUri = uri
                                    if (Build.VERSION.SDK_INT >= 30) {
                                        cropUri = getSDK30PictureUri()
                                        srcUri = originalPhotoForChoose
                                    }
                                    startPhotoCrop(srcUri!!, cropUri!!, 200, 200, CODE_CROP_BIG_PICTURE)
                                }
                            } else {
//                                    WidgetUtils.showToast(parentActivity, HINT_FOR_SDCARD_ERROR + "[2]", ToastType.WARN);
                            }
                        } else {
//                                WidgetUtils.showToast(parentActivity, HINT_FOR_SDCARD_ERROR + "[3]", ToastType.WARN);
                        }
                    } else {
                        // The File corresponding to the original photo's URI
                        val originalPhotoSrc = FileUtils.uri2File(mActivity.applicationContext, originalPhotoForChoose)
                        if (TextUtils.isEmpty(originalPhotoSrc)) {
                            return@ActivityResultListener false
                        } else {
                            processResult(originalPhotoSrc)
                            return@ActivityResultListener true
                        }
                    }
                } else if (requestCode == CODE_CROP_BIG_PICTURE) {
                    if (Build.VERSION.SDK_INT >= 30) {
                        processResult(_mCropImgPath!!)
                    } else {
                        processResult(_tempImageFileLocation!!)
                    }
                }
                false
            }
        })
    }

    override fun onDetachedFromActivityForConfigChanges() {

    }

    private fun processResult(content: String) {
        if (mResult == null) return
        mResult!!.success(content)
        mResult = null
    }


    fun takePhoto(activity: Activity, requestCode: Int, uriToBeSave: Uri?) {
        if (uriToBeSave == null) {
            Log.e(TAG, "uriToBeSave is null!")
            return
        }
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val photoURI = FileProvider.getUriForFile(mActivity, mActivity.getPackageName().toString() + ".fileprovider",
                    File(_tempImageFileLocation))
            intent.putExtra(MediaStore.EXTRA_OUTPUT, photoURI)
        } else {
            intent.putExtra(MediaStore.EXTRA_OUTPUT, uriToBeSave)
        }
        intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        activity.startActivityForResult(intent, requestCode)
    }

    fun takeVideo(activity: Activity, requestCode: Int, uriToBeSave: Uri?) {
        val takeVideoIntent = Intent(MediaStore.ACTION_VIDEO_CAPTURE)
        if (takeVideoIntent.resolveActivity(mActivity!!.packageManager) != null) {
            takeVideoIntent.putExtra("camerasensortype", 2) // Invoke the front camera
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val videoURI = FileProvider.getUriForFile(mActivity, mActivity.getPackageName().toString() + ".fileprovider",
                        File(_tempImageFileLocation))
                takeVideoIntent.putExtra(MediaStore.EXTRA_OUTPUT, videoURI)
            } else {
                takeVideoIntent.putExtra(MediaStore.EXTRA_OUTPUT, getTempImageFileUri(".mp4"))
            }
            mActivity!!.startActivityForResult(takeVideoIntent, requestCode)
        }
    }

    fun choosePhoto(activity: Activity, requestCode: Int) {
        val intent = Intent()
        if (Build.VERSION.SDK_INT >= 30) {
            intent.action = Intent.ACTION_OPEN_DOCUMENT
            intent.addCategory(Intent.CATEGORY_OPENABLE)
        } else {
            intent.action = Intent.ACTION_GET_CONTENT
        }
        intent.type = "image/*"
        activity.startActivityForResult(intent, requestCode)
    }

    private fun getTempImageFileUri(fileSuffix: String): Uri? {
        val tempImageFileLocation = getTempImageFileLocation(fileSuffix)
        return if (tempImageFileLocation != null) {
            Uri.parse("file://$tempImageFileLocation")
        } else null
    }


    private fun getTempImageFileLocation(fileSuffix: String): String? {
        try {
            if (_tempImageFileLocation == null) {
                val avatarTempDirStr = getPicSavedDir()
                val avatarTempDir = File(avatarTempDirStr)
                if (avatarTempDir != null) {
                    // Create the directory if it doesn't exist.
                    if (!avatarTempDir.exists()) avatarTempDir.mkdirs()

                    // Temporary file name
                    _mFileName = System.currentTimeMillis().toString() + fileSuffix
                    _tempImageFileLocation = avatarTempDir.absolutePath + "/" + _mFileName
                    if (Build.VERSION.SDK_INT >= 30) {
                        val tempFile = File(_tempImageFileLocation)
                        if (!tempFile.exists()) {
                            if (tempFile.createNewFile()) {
                                _tempImageFileLocation = tempFile.absolutePath
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "【Pic】Encountered an error while trying to read the temporary storage path for local user images," + e.message, e)
        }
        Log.d(TAG, "【Pic】Currently retrieving the temporary storage path for local user images: $_tempImageFileLocation")
        return _tempImageFileLocation
    }

    private fun getPicSavedDir(): String? {
        var dir: String? = null
        dir = if (Environment.MEDIA_MOUNTED == Environment.getExternalStorageState() || !Environment.isExternalStorageRemovable()) {
            if (mIsNeedCrop && Build.VERSION.SDK_INT >= 30) {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES).absolutePath
            } else {
                mActivity!!.getExternalFilesDir(Const.DIR_YLNEW_APP_FILES_PIC_DIR)!!.absolutePath
            }
        } else {
            //External storage is not available
            mActivity!!.filesDir.absolutePath + Const.DIR_YLNEW_APP_FILES_PIC_DIR
        }
        //        LogUtils.e("dir = " + dir);
        return dir
    }

    /**
     * Initiate photo cropping
     */
    private fun startPhotoCrop(srcUri: Uri, cropUri: Uri, outputX: Int, outputY: Int, requestCode: Int) {
        val intent = Intent("com.android.camera.action.CROP")
        intent.flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        //Set source URI
        intent.setDataAndType(srcUri, "image/*")
        intent.putExtra("crop", "true")
        intent.putExtra("aspectX", 1)
        intent.putExtra("aspectY", 1)
        //        intent.putExtra("outputX", outputX);
//        intent.putExtra("outputY", outputY);
        intent.putExtra("scale", true)
        //        //Set image format
//        intent.putExtra("outputFormat", Bitmap.CompressFormat.JPEG.toString());
        intent.putExtra("return-data", false) //No need to return data to avoid exceptions due to large images
        intent.putExtra("noFaceDetection", true) // no face detection
        //Set destination URI
        intent.putExtra(MediaStore.EXTRA_OUTPUT, cropUri)
        mActivity!!.startActivityForResult(intent, requestCode)
    }

    private fun getSDK30PictureUri(): Uri? {
        val pictureDirectory = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        if (!pictureDirectory.exists()) {
            pictureDirectory.mkdirs()
        }
        val imgFile = File(pictureDirectory.absolutePath + File.separator + _mFileName)
        try {
            if (!imgFile.exists()) {
                imgFile.createNewFile()
            }
        } catch (e: Exception) {
            Log.e("ox_debug", e.message, e)
        }
        _mCropImgPath = imgFile.absolutePath
        // Insert the file using the MediaStore API to obtain the URI where the system crop should be saved (since the app doesn't have permission to access public storage and needs to use the MediaStore API for operations)
        val values = ContentValues()
        values.put(MediaStore.Images.Media.DATA, _mCropImgPath)
        values.put(MediaStore.Images.Media.DISPLAY_NAME, _mFileName)
        values.put(MediaStore.Images.Media.MIME_TYPE, "image/*")
        return mActivity!!.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
    }

    private fun getCompressionImg(filePath: String, quality: Int) {
        var bitmap: Bitmap? = null
        try {
            val opts = BitmapFactory.Options()
            opts.inJustDecodeBounds = false
            bitmap = BitmapUtils.loadLocalBitmap(filePath, opts)
        } catch (e: Exception) {
            Log.e("ox_debug", e.message, e)
        }
        if (bitmap == null) mResult!!.success(null)
        val path: String = FileUtils.getFileSavedDir(mActivity, Const.DIR_YLNEW_APP_FILES_PIC_DIR).toString() + "/" + System.currentTimeMillis() + ".png"
        val isSaveSucc: Boolean = FileUtils.saveBitmap(bitmap, File(path), Bitmap.CompressFormat.JPEG, quality)
        if (isSaveSucc) {
            mResult!!.success(path)
        } else {
            mResult!!.success(null)
        }
    }

    private fun goSysShare(filePath: String) {
        var shareFileURI: Uri? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            shareFileURI = FileProvider.getUriForFile(mActivity, mActivity.getPackageName().toString() + ".fileprovider",
                    File(filePath))
        } else {
            shareFileURI = Uri.fromFile(File(filePath))
        }
        var shareIntent: Intent = Intent(Intent.ACTION_SEND);
        if (shareFileURI != null) {
            shareIntent.putExtra(Intent.EXTRA_STREAM, shareFileURI)
            shareIntent.type = "image/*"
            //Use sms_body to get text when the user selects SMS
            shareIntent.putExtra("sms_body", "")
        } else {
            shareIntent.type = "text/plain"
        }
        shareIntent.putExtra(Intent.EXTRA_TEXT, "")
        //Customize the title of the selection box
        mActivity.startActivity(Intent.createChooser(shareIntent, "Share"))
    }

}