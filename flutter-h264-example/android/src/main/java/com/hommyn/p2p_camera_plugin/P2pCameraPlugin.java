package com.hommyn.p2p_camera_plugin;

import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaCodecList;
import android.media.MediaFormat;
import android.util.Log;
import android.view.Surface;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;

import io.flutter.plugin.common.BasicMessageChannel;
import io.flutter.plugin.common.BinaryCodec;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.view.TextureRegistry;

import static android.content.ContentValues.TAG;

/**
 * FlutterPlugin
 */
public class P2pCameraPlugin implements MethodCallHandler, BasicMessageChannel.MessageHandler<ByteBuffer> {

    private MediaCodec codec;

    private TextureRegistry.SurfaceTextureEntry textureEntry;
    private long textureId;
    private Surface surface;
    private MediaFormat mediaFormat;
    private EventChannel.EventSink codecAvailableInputBufferEvent;

//    private static class P2PPlayer {
//        private Surface surface;
//        private final SurfaceTextureEntry textureEntry;
//
//        private MediaCodec codec;
//        MediaFormat mediaFormat;
//        long textureId;
//        byte[] fileBytes;
//        int encodedFileOffset = 0;
//        //int encodedFileOffset = 76283; // BAD!
//        //int encodedFileOffset = 960048; // BAD!!
//        int presentationTime = 0;
//        int outputBufferPresentationTime = 0;
//        int inputBufferCount = 0;
//        int outputBufferCount = 0;
//
//        // from avconv, when streaming sample.h264.mp4 from disk
//        byte[] header_sps = {
//                (byte) 0x00, (byte) 0x00, (byte) 0x00, (byte) 0x01,
//                (byte) 0x67,
//                (byte) 0x42, (byte) 0xc0, (byte) 0x1f, (byte) 0x9d, (byte) 0xa8, (byte) 0x14, (byte) 0x01, (byte) 0x6e,
//                (byte) 0x84, (byte) 0x00, (byte) 0x00, (byte) 0x03, (byte) 0x00, (byte) 0x04, (byte) 0x00, (byte) 0x00,
//                (byte) 0x03, (byte) 0x00, (byte) 0x50, (byte) 0x10};
//
//        byte[] header_pps = {
//                (byte) 0x00, (byte) 0x00, (byte) 0x00, (byte) 0x01,
//                (byte) 0x68,
//                (byte) 0xee, (byte) 0x3c, (byte) 0x80};
//
//        P2PPlayer(
//                Context context,
//                TextureRegistry.SurfaceTextureEntry textureEntry
//        ) {
//            try {
//                //InputStream file = getAssets().open("video.h264");
//                //AssetManager assetManager = getAssets();
//                InputStream file = context.getAssets().open("video.264");
//                fileBytes = new byte[file.available()];
//                file.read(fileBytes);
//                file.close();
//            } catch (IOException e) {
//                Log.e("FUCK", "Error file read!");
//            }
//
//            this.textureEntry = textureEntry;
//            this.surface = new Surface(textureEntry.surfaceTexture());
//
//            try {
//                codec = MediaCodec.createDecoderByType("video/avc");
//            } catch (IOException e) {
//                Log.println(0, "FUCK", "Hi!");
//            }
//
//            codec.setCallback(new MediaCodec.Callback() {
//                @Override
//                public void onInputBufferAvailable(MediaCodec codec, int index) {
//                    inputBufferCount++;
//                    if (encodedFileOffset + 10000 < fileBytes.length) {
//                        Log.i("FUCK", "onInputBufferAvailable: " + index + ":" + inputBufferCount + " : " + encodedFileOffset + "=" + String.format("0x%02X", fileBytes[encodedFileOffset + 4]));
//                    }
//                    ByteBuffer buffer = codec.getInputBuffer(index);
//                    buffer.clear();
//                    byte firstByte = fileBytes[encodedFileOffset];
//                    int nextOffset = 0;
//
//                    // find next nal unit
//                    if (encodedFileOffset + nextOffset + 4 > fileBytes.length) {
//                        //buffer.put(fileBytes, encodedFileOffset, nextOffset);
//                        Log.i("FUCK", "**** END *********************");
//                        codec.queueInputBuffer(index, 0, 0, 0, BUFFER_FLAG_END_OF_STREAM);
//                        return;
//                    }
//                    if (fileBytes[encodedFileOffset + nextOffset] == 0x00
//                            && fileBytes[encodedFileOffset + nextOffset + 1] == 0x00
//                            && fileBytes[encodedFileOffset + nextOffset + 2] == 0x00
//                            && fileBytes[encodedFileOffset + nextOffset + 3] == 0x01
//                            && (fileBytes[encodedFileOffset + nextOffset + 4] & 0x80) != 0x80
//                    ) {
//                        nextOffset += 4;
//                        while ((fileBytes[encodedFileOffset + nextOffset] != 0x00
//                                || fileBytes[encodedFileOffset + nextOffset + 1] != 0x00
//                                || fileBytes[encodedFileOffset + nextOffset + 2] != 0x00
//                                || fileBytes[encodedFileOffset + nextOffset + 3] != 0x01
//                                || (fileBytes[encodedFileOffset + nextOffset + 4] & 0x80) == 0x80)) {
//                            nextOffset++;
//
//                            if (encodedFileOffset + nextOffset + 4 > fileBytes.length) {
//
//                                break;
//                            }
//                        }
//                    } else {
//                        Log.i("FUCK", "WTF???!!!!!!!!!!!!!!");
//                    }
//
//                    if (encodedFileOffset + nextOffset + 4 > fileBytes.length) {
//                        //buffer.put(fileBytes, encodedFileOffset, nextOffset);
//                        codec.queueInputBuffer(index, 0, 0, 0, BUFFER_FLAG_END_OF_STREAM);
//                    } else {
//                        //buffer.put(fileBytes, encodedFileOffset, encodedFileOffset + nextOffset);
//                        buffer.put(fileBytes, encodedFileOffset, nextOffset);
//                        if(fileBytes[encodedFileOffset + 4] == 0x41 || fileBytes[encodedFileOffset + 4] == 0x65) {
//                            codec.queueInputBuffer(index, 0, nextOffset-32, presentationTime, 0);
//                        }else{
//                            codec.queueInputBuffer(index, 0, nextOffset, presentationTime, 0);
//
//                        }
//                        //codec.queueInputBuffer(index, 0, nextOffset, 0, 0);
//                    }
//                    //for(int i = 0; i < 10000000; i++) {
//                    //}
//                    presentationTime += 400000;
//                    encodedFileOffset += nextOffset;
//                }
//
//                @Override
//                public void onOutputBufferAvailable(MediaCodec codec, int index, MediaCodec.BufferInfo info) {
//                    outputBufferCount++;
//                    Log.i("FUCK", "onOutputBufferAvailable :" + index + ":" + outputBufferCount + " Flags: " + info.flags);
//                    ByteBuffer outputBuffer = codec.getOutputBuffer(index);
//                    MediaFormat bufferFormat = codec.getOutputFormat(index);
//                    codec.releaseOutputBuffer(index, info.presentationTimeUs);
//                    //codec.releaseOutputBuffer(index, true);
//                    outputBufferPresentationTime++;
//                    Log.i("FUCK", "==========================");
//                }
//
//                @Override
//                public void onError(MediaCodec codec, MediaCodec.CodecException e) {
//                    Log.i("FUCK", "onError");
//                }
//
//                @Override
//                public void onOutputFormatChanged(MediaCodec codec, MediaFormat format) {
//                    Log.i("FUCK", "onOutputFormatChanged");
//                }
//            });
//
//            mediaFormat = MediaFormat.createVideoFormat("video/avc", 1280, 720);
//            mediaFormat.setByteBuffer("csd-0", ByteBuffer.wrap(header_sps));
//            mediaFormat.setByteBuffer("csd-1", ByteBuffer.wrap(header_pps));
//            surface = new Surface(textureEntry.surfaceTexture());
//            textureId = textureEntry.id();
//            codec.configure(mediaFormat, surface, null, 0);
//            codec.start();
//        }
//
//
//    }

    private P2pCameraPlugin(Registrar registrar) {
        this.registrar = registrar;
    }

    private final Registrar registrar;


    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final P2pCameraPlugin plugin = new P2pCameraPlugin(registrar);
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "p2p-camera");
        channel.setMethodCallHandler(plugin);

        final BasicMessageChannel<ByteBuffer> binaryChannel =  new BasicMessageChannel<>(registrar.messenger(), "p2p-camera/buffers", BinaryCodec.INSTANCE);
        binaryChannel.setMessageHandler(plugin);

    }

    /// Available Buffer list
    LinkedList<Integer> availableInputBuffers;

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        TextureRegistry textures = registrar.textures();
        if (textures == null) {
            result.error("no_activity", "HOMMYN P2P plugin requires a foreground activity", null);
            return;
        }
        if (call.method.equals("getPlatformVersion")) {
            result.success(android.os.Build.VERSION.RELEASE);
        }


        // Creates a new Flutter Texture entry and attach an Android Surface to it
        if (call.method.equals("getTexture")) {
            this.textureEntry = textures.createSurfaceTexture();
            this.textureId = textureEntry.id();
            this.surface = new Surface(textureEntry.surfaceTexture());
            if (this.surface != null && textureId >= 0) {
                result.success(this.textureId);
            } else {
                result.error("0x8000000", "Error initializing structure", "Error initializing structure details");
            }
        }

        // Get a list of all supported decoder codecs
        if (call.method.equals("getPlatformCodecs")) {
            final List<String> codecs = new ArrayList<>();

            MediaCodecList mediaCodecList = new MediaCodecList(MediaCodecList.ALL_CODECS);
            MediaCodecInfo[] codecInfos = mediaCodecList.getCodecInfos();
            for (MediaCodecInfo codecInfo : codecInfos) {
                if (!codecInfo.isEncoder()) {
                    codecs.add(codecInfo.getName());
                }
            }
            result.success(codecs);
        }


        // Init Mediacodec and CallBack functions
        if (call.method.equals("initCodec")) {
            String codecType = call.argument("codecType");
            boolean res = false;
            availableInputBuffers = new LinkedList<>();
            try {
                codec = MediaCodec.createDecoderByType(codecType);
                codec.setCallback(new MediaCodec.Callback() {
                    @Override
                    public void onInputBufferAvailable(MediaCodec codec, int index) {
                        //Log.i("MEDIA_CODEC", "onInputBufferAvailable: " + index);
                        availableInputBuffers.add(index);
                        //codecAvailableInputBufferEvent.success(index);
                    }

                    @Override
                    public void onOutputBufferAvailable(MediaCodec codec, int index, MediaCodec.BufferInfo info) {
                        //Log.i("MEDIA_CODEC", "onOutputBufferAvailable: " + index);
                        codec.releaseOutputBuffer(index, info.presentationTimeUs);
                    }

                    @Override
                    public void onError(MediaCodec codec, MediaCodec.CodecException e) {
                        Log.i("MEDIA_CODEC", "onError" + e.toString());
                    }

                    @Override
                    public void onOutputFormatChanged(MediaCodec codec, MediaFormat format) {
                        Log.i("MEDIA_CODEC", "onOutputFormatChanged" + format.toString());
                    }
                });
                res = true;
            } catch (IOException e) {
                Log.println(0, "P2P-PLUGIN", "Error initializing codec");
            }
            result.success(res);
        }

        if (call.method.equals("setMediaFormat")) {
            byte[] csd0 = call.argument("csd0");
            byte[] csd1 = call.argument("csd1");

            this.mediaFormat = MediaFormat.createVideoFormat("video/avc", 1280, 720);
            this.mediaFormat.setByteBuffer("csd-0", ByteBuffer.wrap(csd0));
            this.mediaFormat.setByteBuffer("csd-1", ByteBuffer.wrap(csd1));
            result.success(null);
        }

        if(call.method.equals("registerAvailableBufferEventStream")){
            final EventChannel eventChannel = new EventChannel(registrar.messenger(), "p2p-camera/codec-stream");
            eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
                @Override
                public void onListen(Object args, final EventChannel.EventSink events) {
                    Log.w(TAG, "adding listener");
                    codecAvailableInputBufferEvent = events;
                }

                @Override
                public void onCancel(Object args) {
                    Log.w(TAG, "cancelling listener");
                }
            });
            result.success(null);
        }
        // Configure and Start Codec
        if (call.method.equals("start")) {
            //codec.reset();
            try {
                codec.configure(mediaFormat, surface, null, 0);
            } catch (Exception e) {
                Log.println(0, "P2P-PLUGIN", "Error configuring codec: " + e.toString());
            }
            codec.start();

            // TODO: Handle errors on configure and start
            result.success(null);
        }


//        if (call.method.equals("init")) {
//            TextureRegistry.SurfaceTextureEntry handle = textures.createSurfaceTexture();
//            P2PPlayer player = new P2PPlayer(
//                    registrar.context(),
//                    handle
//            );
//            result.success(player.textureId);
//        } else {
//            result.notImplemented();
//        }
    }


    // Binary Channel
    @Override
    public void onMessage(ByteBuffer byteBuffer, BasicMessageChannel.Reply<ByteBuffer> reply) {
        if(!availableInputBuffers.isEmpty()) {
            int index = availableInputBuffers.removeFirst();
            ByteBuffer buffer = codec.getInputBuffer(index);
            buffer.clear();
            buffer.put(byteBuffer);
            int fuck = byteBuffer.capacity();
            codec.queueInputBuffer(index, 0, byteBuffer.capacity(), 0, 0);
        }
        reply.reply(null);
    }
}