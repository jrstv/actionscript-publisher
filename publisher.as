package {
  import flash.display.Sprite;
  import flash.display.StageAlign;
  import flash.display.StageScaleMode;
  import flash.events.Event;
  import flash.events.StatusEvent;
  import flash.events.NetStatusEvent;
  import flash.external.ExternalInterface;
  import flash.media.Camera;
  import flash.media.Microphone;
  import flash.media.Video;
  import flash.net.NetConnection;
  import flash.net.NetStream;
  import flash.net.ObjectEncoding;
  import flash.media.VideoStreamSettings;
  import flash.media.H264VideoStreamSettings;
  import flash.media.H264Level;
  import flash.media.H264Profile;
  import flash.media.SoundCodec;
  import mx.utils.ObjectUtil;
  import flash.utils.getTimer;
  import flash.utils.setInterval;
  import flash.utils.setTimeout;
  import flash.utils.clearInterval;
  import flash.system.Security;

  Security.allowDomain('*');

  public class publisher extends Sprite {
    protected var video:Video;
    protected var connection:NetConnection;
    protected var netStream:NetStream;
    protected var camera:Camera;
    protected var microphone:Microphone;
    protected var options:Object = {
      serverURL: null
    , streamName: null
    , streamWidth: 1280
    , streamHeight: 720
    , streamFPS: 30
    , keyFrameInterval: 120
    , bandwidth: 2048 * 1024 * 8          // bps
    , videoQuality: 75                    // % percentage
    , videoCodec: "Sorensen"
    , h264Profile: H264Profile.MAIN       // only valid when videoCodec is H264Avc
    , h264Level: H264Level.LEVEL_3_1      // only valid when videoCodec is H264Avc
    , audioCodec: SoundCodec.NELLYMOSER
    , audioSampleRate: 44                 // kHz
    , microphoneSilenceLevel: 0
    , microphoneLoopBack: false
    , jsLogFunction: "console.log"
    , jsEmitFunction: null
    , embedTimecode: true
    , timecodeFrequency: 100
    };

    /**
     * the timestamp of when the recording started.
     */
    protected var _timecodeIntervalHandle:uint;
    protected var _recordStartTime:uint;
    protected var _isPreviewing:Boolean = false;
    protected var _isPublishing:Boolean = false;
    // _cameraStreaming is changed when the user clicks allow, or it is already allowed
    // we need this because otherwise ffmpeg detects an audio stream
    // and a data stream
    // and it then drops the video stream on the floor
    // so we need to wait for the video stream to start streaming
    // then we can start sending data
    protected var _hasMediaAccess:Boolean = false;

    public function publisher() {
      log("Initializing ...");

      stage.align = StageAlign.TOP_LEFT;
      stage.scaleMode = StageScaleMode.NO_SCALE;

      this.connection = new NetConnection();
      this.connection.objectEncoding = ObjectEncoding.AMF0;
      this.connection.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus, false, 0, true);

      if (ExternalInterface.available) {
        ExternalInterface.addCallback("trace", this.log);
        ExternalInterface.addCallback("getOptions", this.getOptions);
        ExternalInterface.addCallback("setOptions", this.setOptions);
        ExternalInterface.addCallback("sendData", this.sendTextData);
        ExternalInterface.addCallback("sendCuePoint", this.sendCuePoint);
        ExternalInterface.addCallback("start", this.start);
        ExternalInterface.addCallback("stop", this.stop);
        ExternalInterface.addCallback("preview", this.preview);
      } else {
        log("External interface not available.");
      }
    }

    // https://github.com/KAPx/krecord/compare/KAPx:kapx...kapx-rtmp-timecode-events
    private function embedTimecode():void {
      var timeCode:uint = getTimer() - _recordStartTime;
      var now:Date = new Date();
      var msTimeStamp:Number = now.getTime();
      // log('embedTimecode: offset - ' + timeCode.toString() + " time - "+ msTimeStamp);
      sendTextData({ timecode: timeCode, timestamp: msTimeStamp });
    }


    public function sendCuePoint(cuePointData:Object):Boolean {
      return sendData("onCuePoint", cuePointData);
    }

    /**
     * Send an 'onTextData' message on the NetStream.
     */
    public function sendTextData(data:Object):Boolean{
        if (!('text' in data)) {
          data.text = '';
        }
        if (!('language' in data)) {
          data.language = 'eng';
        }
        return sendData("onTextData", data);
    }

    private function sendData(handle:String, data:Object):Boolean{
      if (!_hasMediaAccess) {
        return false;
      }
      if (!_isPublishing) {
        return false;
      }
      // log("sending data - " + ObjectUtil.toString(data));
      this.netStream.send(handle, data);
      return true;
    }

    // log to the JavaScript console
    public function log(... arguments):void {
      var applyArgs:Array = [options.jsLogFunction, "publisher:"].concat(arguments);
      ExternalInterface.call.apply(this, applyArgs);
    }

    // log to the JavaScript console
    public function emit(... arguments):void {
      var applyArgs:Array = [options.jsEmitFunction].concat(arguments);
      ExternalInterface.call.apply(this, applyArgs);
    }


    // External APIs -- invoked from JavaScript

    public function getOptions():Object {
      return this.options;
    }

    public function setOptions(options:Object):void {
      log("Received options:", options)
      for(var p:String in options) {
        if (options[p] != null) {
          this.options[p] = options[p];
        }
      }
    }

    public function start():void {
      emit("status", "Connecting to url: " + this.options.serverURL);
      this.connection.connect(this.options.serverURL);
    }

    public function preview():void {
      emit("status", "Previewing.");
      if(this._isPreviewing){
        return;
      }
      var videoDimensions:Object = getVideoDimensions();
      log("Video dimensions:", videoDimensions.width, "x", videoDimensions.height);
      this.video = new Video(videoDimensions.width, videoDimensions.height);
      if (this.numChildren > 0) { this.removeChildAt(0); }
      this.addChild(this.video);

      // set up the camera and video object
      this.microphone = getMicrophone();
      this.camera = getCamera();
      this._hasMediaAccess = !camera.muted;
      camera.addEventListener(StatusEvent.STATUS, onCameraStatus);

      // attach the camera to the video
      this.video.attachCamera(camera);
      this._isPreviewing = true;

    }

    public function stop():void {
      clearInterval(this._timecodeIntervalHandle);
      if (this.netStream) { this.netStream.close(); }
      if (this.connection.connected) { this.connection.close(); }
      this.video.clear();
      this.video.attachCamera(null);
      this._isPublishing = false;
    }


    // set up the microphone and camera

    private function getMicrophone():Microphone {
      var microphone:Microphone = Microphone.getMicrophone();
      microphone.codec = this.options.audioCodec;
      microphone.rate = this.options.audioSampleRate;
      microphone.setSilenceLevel(this.options.microphoneSilenceLevel);
      microphone.setLoopBack(this.options.microphoneLoopBack)

      log("Audio Codec:", this.options.audioCodec);
      log("Audio Sample Rate:", this.options.audioSampleRate);
      log("Microphone Silence Level:", this.options.microphoneSilenceLevel);
      log("Microphone Loopback:", this.options.microphoneLoopback);

      return microphone;
    }

    private function getCamera():Camera {
      var camera:Camera = Camera.getCamera();
      camera.setMode(this.options.streamWidth, this.options.streamHeight, this.options.streamFPS, true);
      camera.setQuality(this.options.bandwidth, this.options.videoQuality);
      camera.setKeyFrameInterval(this.options.keyFrameInterval);

      return camera;
    }

    private function getVideoStreamSettings():VideoStreamSettings {
      // configure streaming settings -- match to camera settings
      var videoStreamSettings:VideoStreamSettings;
      if (this.options.videoCodec == "H264Avc") {
        var h264VideoStreamSettings:H264VideoStreamSettings = new H264VideoStreamSettings();
        h264VideoStreamSettings.setProfileLevel(this.options.h264Profile, this.options.h264Level);
        videoStreamSettings = h264VideoStreamSettings;
      } else {
        videoStreamSettings = new VideoStreamSettings();
      }
      videoStreamSettings.setQuality(this.options.bandwidth, this.options.videoQuality);
      videoStreamSettings.setKeyFrameInterval(this.options.keyFrameInterval);
      videoStreamSettings.setMode(this.options.streamWidth, this.options.streamHeight, this.options.streamFPS);

      log("Video Codec:", this.netStream.videoStreamSettings.codec);
      if (this.netStream.videoStreamSettings.codec == "H264Avc") {
        log("H264 Profile:", this.options.h264Profile);
        log("H264 Level:", this.options.h264Level);
      }
      log("Resolution:", this.options.streamWidth, "x", this.options.streamHeight);
      log("Frame rate:", this.options.streamFPS, "fps");
      log("Keyframe interval:", this.options.keyFrameInterval);
      log("Bandwidth:", this.options.bandwidth, "bps");
      log("Quality:", this.options.videoQuality, "%");

      return videoStreamSettings;
    }


    private function getVideoDimensions():Object {
      log("Stage dimensions:", stage.stageWidth, "x", stage.stageHeight);
      var width:int, height:int;
      var stageAR:Number = stage.stageWidth / stage.stageHeight;
      var streamAR:Number = this.options.streamWidth / this.options.streamHeight;
      if (streamAR >= stageAR) { // too wide
        width = stage.stageWidth;
        height = Math.round(width / streamAR);
      } else if (streamAR < stageAR) { // too tall
        height = stage.stageHeight;
        width = Math.round(height * streamAR);
      }

      return {
        width: width
      , height: height
      };
    }


    // publish the stream to the server
    public function publish():void {
      emit("status", "About to publish stream ...");

      try {
        preview();

        // attach the camera and microphone to the stream
        this.netStream = new NetStream(this.connection);
        this.netStream.attachCamera(this.camera);
        this.netStream.attachAudio(this.microphone);
        this.netStream.videoStreamSettings = getVideoStreamSettings();
        log("Video Codec:", this.netStream.videoStreamSettings.codec);

        // start publishing the stream
        this.netStream.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus, false, 0, true);
        if (this._hasMediaAccess){
          startPublishing();
        }
      } catch (err:Error) {
        log("ERROR:", err);
        emit("error", err);
      }
    }

    private function onCameraStatus(event:StatusEvent):void {
      switch (event.code) {
        case "Camera.Muted":
          trace("User clicked Deny.");
          break;
        case "Camera.Unmuted":
          this._hasMediaAccess = true;
          startPublishing();
          trace("User clicked Accept.");
          break;
        }
    }

    private function startPublishing():void{
      try {
        log("Publishing to:", this.options.streamName);
        // set the initial timer
        this._recordStartTime = getTimer()
        this.netStream.publish(this.options.streamName);

        if (this.options.embedTimecode) {
          trace('embedding recording timecode');
          this._timecodeIntervalHandle = setInterval(embedTimecode, this.options.timecodeFrequency);
        }
      } catch (err:Error) {
        log("ERROR:", err);
        emit("error", err);
      }
    }

    // respond to network status events
    private function onNetStatus(event1:NetStatusEvent):void {
      switch (event1.info.code) {
        case "NetConnection.Connect.Success":
          emit("connect", "Connected to the RTMP server.");
          publish();
          break;
        case "NetConnection.Connect.Failed":
          emit("error", "Couldn't connect to the RTMP server.");
          break;

        case "NetConnection.Connect.Closed":
          emit("disconnect", "Disconnected from the RTMP server.");
          break;

        case "NetStream.Publish.Start":
          this._isPublishing = true;
          emit("publish", "Publishing started.")
          break;

        case "NetStream.Failed":
          emit("error", "Couldn't stream to endpoint (fail).");
          stop();
          break;

        case "NetStream.Publish.Denied":
          log("error", "Couldn't stream to endpoint (deny).");
          emit("error", "Couldn't stream to endpoint (deny).");
          stop();
          break;

        default:
          log("NetStatusEvent: " + event1.info.code);
          break;
      }
    }
  }
}
