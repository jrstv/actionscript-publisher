package {
	import flash.display.Sprite;
	import flash.events.Event;
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


  public class recorder extends Sprite {
    protected var video:Video;
    protected var connection:NetConnection;
    protected var netStream:NetStream;
    protected var options:Object = {
      serverURL: null
    , streamName: null
    , streamKey: null
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
    };


  	public function recorder() {
      cLog("Initializing ...");

      this.video = new Video();
      this.addChild(this.video);
      this.connection = new NetConnection();
      this.connection.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus, false, 0, true);
      this.connection.objectEncoding = ObjectEncoding.AMF0;

      if (ExternalInterface.available) {
      	ExternalInterface.addCallback("trace", this.cLog);
        ExternalInterface.addCallback("getOptions", this.getOptions);
        ExternalInterface.addCallback("setOptions", this.setOptions);
      	ExternalInterface.addCallback("start", this.start);
      	ExternalInterface.addCallback("stop", this.stop);
    	} else {
    		cLog("External interface not available.");
    	}
  	}

    protected function getVideoWidth():int {
      // match our video width to our height, but with the right aspect ratio
      return Math.round(this.options.streamWidth / this.options.streamHeight * getVideoHeight());
    }

    protected function getVideoHeight():int {
      // lock our height at 240px
      return 240;
    }

    protected function getEdgecastStreamEndpoint():String {
      return this.options.streamName + "?" + this.options.streamKey + "&adbe-live-event=" + this.options.streamName;
    }


    // log to the JavaScript console
    public function cLog(... arguments):void {
      var applyArgs:Array = ["console.log", "recorder:"].concat(arguments);
      ExternalInterface.call.apply(this, applyArgs);
    }


  	// External APIs -- invoked from JavaScript

    public function getOptions():Object {
      return this.options;
    }

    public function setOptions(options:Object):void {
      for(var p:String in options) {
        if (options[p] != null) {
          this.options[p] = options[p];
        }
      }
    }

  	public function start():void {
  		cLog("Connecting to url: " + this.options.serverURL);
  		this.connection.connect(this.options.serverURL);
  	}

  	public function stop():void {
      if (this.netStream) { this.netStream.close(); }
      if (this.connection.connected) { this.connection.close(); }
      this.video.attachCamera(null);
      this.video.clear();
  	}


    // set up the microphone and camera

    private function getMicrophone():Microphone {
      var microphone:Microphone = Microphone.getMicrophone();
      microphone.codec = this.options.audioCodec;
      microphone.rate = this.options.audioSampleRate;
      microphone.setSilenceLevel(this.options.microphoneSilenceLevel);
      microphone.setLoopBack(this.options.microphoneLoopBack)

      cLog("Audio Codec:", this.options.audioCodec);
      cLog("Audio Sample Rate:", this.options.audioSampleRate);
      cLog("Microphone Silence Level:", this.options.microphoneSilenceLevel);
      cLog("Microphone Loopback:", this.options.microphoneLoopback);

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

      cLog("Video Codec:", this.netStream.videoStreamSettings.codec);
      if (this.netStream.videoStreamSettings.codec == "H264Avc") {
        cLog("H264 Profile:", this.options.h264Profile);
        cLog("H264 Level:", this.options.h264Level);
      }
      cLog("Resolution:", this.options.streamWidth, "x", this.options.streamHeight);
      cLog("Frame rate:", this.options.streamFPS, "fps");
      cLog("Keyframe interval:", this.options.keyFrameInterval);
      cLog("Bandwidth:", this.options.bandwidth, "bps");
      cLog("Quality:", this.options.videoQuality, "%");

      return videoStreamSettings;
    }


    // publish the stream to the server
    public function publish():void {
      cLog("About to Publish Stream");

      try {
        // set up the camera and video object
        var microphone:Microphone = getMicrophone();
        var camera:Camera = getCamera();

        // attach the camera to the video
        this.video.width = getVideoWidth();
        this.video.height = getVideoHeight();
        this.video.attachCamera(camera);
        cLog("Video dimensions:", getVideoWidth(), "x", getVideoHeight());

        // attach the camera and microphone to the stream
        this.netStream = new NetStream(this.connection);
        this.netStream.attachCamera(camera);
        this.netStream.attachAudio(microphone);
        this.netStream.videoStreamSettings = getVideoStreamSettings();
        cLog("Video Codec:", this.netStream.videoStreamSettings.codec);

        // start publishing the stream
        this.netStream.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus, false, 0, true);
        cLog("Publishing to:", getEdgecastStreamEndpoint());
        this.netStream.publish(getEdgecastStreamEndpoint());
      } catch (err:Error) {
        cLog("ERROR:", err);
      }
    }

    // respond to network status events
  	private function onNetStatus(event1:NetStatusEvent):void {
  		switch (event1.info.code) {
  			case "NetConnection.Connect.Success":
          cLog("Connected to the RTMP server.");
          publish();
  				break;
        case "NetConnection.Connect.Failed":
          cLog("Couldn't connect to the RTMP server.");
          break;

  			case "NetConnection.Connect.Closed":
  				cLog("Disconnected from the RTMP server.");
  				break;

        case "NetStream.Publish.Start":
          cLog("Publishing started.")
          break;

        case "NetStream.Failed":
          cLog("Couldn't stream to endpoint.");
          stop();
          break;

				default:
          cLog("NetStatusEvent: " + event1.info.code);
					break;
			}
		}
  }
}
