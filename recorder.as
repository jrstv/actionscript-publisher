package {
	import com.hurlant.crypto.hash.IHash;

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
	import flash.text.TextField;
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;
	import flash.media.H264VideoStreamSettings;
	import flash.media.H264Level;
	import flash.media.H264Profile;
	import flash.media.SoundCodec;


  public class recorder extends Sprite {
  	protected var sMediaServerURL:String;
    protected var sEventName:String;
    protected var sStreamName:String;
  	protected var sStreamKey:String;
  	protected var streamWidth:int = 1280;
  	protected var streamHeight:int = 720;
    protected var streamFPS:int = 30;
    protected var keyFrameInterval:int = 120;
    protected var cameraQuality:int = 90; // % percentage
    protected var bandwidth:int = 2048; // Kbps

  	protected var oConnection:NetConnection;
  	protected var oMetaData:Object = new Object();
  	protected var oNetStream:NetStream;

  	private var oVideo:Video;
  	private var oCamera:Camera;
  	private var oMicrophone:Microphone;
  	private var statusTxt:TextField = new TextField();

  	public function console_log(string:String):void {
  		ExternalInterface.call("console.log", "recorder: " + string);
  		this.statusTxt.text = string;
  	}

    public function recorder2():void {
      var cam:Camera = Camera.getCamera();
      var vid:Video = new Video();
      vid.attachCamera(cam);
      addChild(vid);
    }

  	public function recorder() {
      console_log("Initializing.");

      // EdgeCast's FMS usees the FCPublish protocol after connecting before streaming
      //NetConnection.prototype.onFCPublish = onFCPublish;

      // set up the camera and video object
      this.oCamera = Camera.getCamera();
      // attempt to determine the best 16:9 aspect ratio and frame rate that the camera can support
      this.oCamera.setMode(160000, 90000, 60, false);
      this.streamWidth = this.oCamera.width;
      this.streamHeight = this.oCamera.height;
      this.streamFPS = this.oCamera.fps;
      console_log("camfps:" + this.oCamera.fps);
      this.oVideo = new Video();
      this.addChild(this.oVideo);

      // set up status text object
      this.statusTxt.width = this.streamWidth;
      this.statusTxt.height = this.streamHeight;
      addChild(this.statusTxt);

      this.oConnection = new NetConnection();
      this.oConnection.addEventListener(NetStatusEvent.NET_STATUS, eNetStatus, false, 0, true);
      this.oConnection.objectEncoding = ObjectEncoding.AMF0;

      if (ExternalInterface.available) {
      	ExternalInterface.addCallback("trace", this.console_log);
      	ExternalInterface.addCallback("setUrl", this.setUrl);
      	ExternalInterface.addCallback("getUrl", this.getUrl);
        ExternalInterface.addCallback("setEventName", this.setEventName);
        ExternalInterface.addCallback("getEventName", this.getEventName);
        ExternalInterface.addCallback("setStreamName", this.setStreamName);
        ExternalInterface.addCallback("getStreamName", this.getStreamName);
      	ExternalInterface.addCallback("setStreamKey", this.setStreamKey);
      	ExternalInterface.addCallback("getStreamKey", this.getStreamKey);
      	ExternalInterface.addCallback("setStreamWidth", this.setStreamWidth);
      	ExternalInterface.addCallback("getStreamWidth", this.getStreamWidth);
      	ExternalInterface.addCallback("setStreamHeight", this.setStreamHeight);
      	ExternalInterface.addCallback("getStreamHeight", this.getStreamHeight);
        ExternalInterface.addCallback("getBandwidth", this.getBandwidth);
        ExternalInterface.addCallback("setBandwidth", this.setBandwidth);
        ExternalInterface.addCallback("getStreamFPS", this.getStreamFPS);
        ExternalInterface.addCallback("setStreamFPS", this.setStreamFPS);
        ExternalInterface.addCallback("getKeyFrameInterval", this.getKeyFrameInterval);
        ExternalInterface.addCallback("setKeyFrameInterval", this.setKeyFrameInterval);
        ExternalInterface.addCallback("getCameraQuality", this.getCameraQuality);
        ExternalInterface.addCallback("setCameraQuality", this.setCameraQuality);
      	ExternalInterface.addCallback("start", this.start);
      	ExternalInterface.addCallback("stop", this.stop);
    	} else {
    		console_log("External interface not available)");
    	}
      console_log("Initialized.");
  	}

    protected function getVideoWidth():int {
      // match our video width to our height, but with the right aspect ratio
      return Math.round(this.streamWidth / this.streamHeight * getVideoHeight());
    }

    protected function getVideoHeight():int {
      // lock our height at 240px
      return 240;
    }

    protected function getEdgecastStreamEndpoint():String {
      return this.sStreamName + "?" + this.sStreamKey + "&adbe-live-event=" + this.sEventName;
    }

  	// External APIs -- invoked from JavaScript

  	public function setUrl(url:String):void {
  		this.sMediaServerURL = url;
  	}

  	public function getUrl():String {
  		return this.sMediaServerURL;
  	}


    public function setEventName(eventName:String):void {
      this.sEventName = eventName;
    }

    public function getEventName():String {
      return this.sEventName;
    }


    public function setStreamName(streamName:String):void {
      this.sStreamName = streamName;
    }

    public function getStreamName():String {
      return this.sStreamName;
    }


  	public function setStreamKey(streamKey:String):void {
  		this.sStreamKey = streamKey;
  	}

  	public function getStreamKey():String {
  		return this.sStreamKey;
  	}


  	public function setStreamWidth(width:int):void {
  		this.streamWidth = width;
  	}

  	public function getStreamWidth():int {
  		return this.streamWidth;
  	}


  	public function setStreamHeight(height:int):void {
  		this.streamHeight = height;
  	}

  	public function getStreamHeight():int {
  		return this.streamHeight;
  	}


    public function setBandwidth(bandwidth:int):void {
      console_log("setting bandwidth");
      this.bandwidth = bandwidth * 1024 / 8;
    }

    public function getBandwidth():int {
      return this.bandwidth;
    }


    public function setStreamFPS(fps:int):void {
      this.streamFPS = fps;
    }

    public function getStreamFPS():int {
      return this.streamFPS;
    }

    public function setKeyFrameInterval(frames:int):void {
      this.keyFrameInterval = frames;
    }

    public function getKeyFrameInterval():int {
      return this.keyFrameInterval;
    }

    public function setCameraQuality(pct:int):void {
      this.cameraQuality = pct;
    }

    public function getCameraQuality():int {
      return this.cameraQuality;
    }


  	public function start():void {
  		console_log("Connecting to url: " + this.sMediaServerURL);
  		this.oConnection.connect(this.sMediaServerURL);
  	}

  	public function stop():void {
      console_log("NetStream.info: " + this.oNetStream.info);
      console_log("Closing stream ...");
      this.oNetStream.close();
      console_log("Closing connection ...");
  		this.oConnection.close();
      console_log("Detaching camera ...");
      this.oVideo.attachCamera(null);
  	}

    public function publish():void {
      console_log("About to Publish Stream");

      console_log("Publishing " + this.streamWidth + "x" + this.streamHeight + "@" + this.streamFPS);
      this.oCamera.setMode(this.streamWidth, this.streamHeight, this.streamFPS, true);
      // bytes per second, % quality
      this.oCamera.setQuality(this.bandwidth, this.cameraQuality);
      this.oCamera.setKeyFrameInterval(this.keyFrameInterval);

      this.oMicrophone = Microphone.getMicrophone();
      this.oMicrophone.codec = SoundCodec.SPEEX;
      this.oMicrophone.rate = 44;
      this.oMicrophone.setSilenceLevel(0);
      this.oMicrophone.encodeQuality = 5;
      this.oMicrophone.framesPerPacket = 2;

      // attach the camera to the video
      this.oVideo.width = getVideoWidth();
      this.oVideo.height = getVideoHeight();
      this.oVideo.attachCamera(this.oCamera);

      // attach the camera and microphone to the stream
      this.oNetStream = new NetStream(this.oConnection);
      this.oNetStream.attachCamera(this.oCamera);
      this.oNetStream.attachAudio(this.oMicrophone);

      // configure streaming settings -- match to camera settings
      /*
      var h264Settings:H264VideoStreamSettings = new H264VideoStreamSettings();
      h264Settings.setProfileLevel(H264Profile.MAIN, H264Level.LEVEL_3_1);
      h264Settings.setQuality(this.bandwidth, this.cameraQuality);
      h264Settings.setKeyFrameInterval(this.keyFrameInterval);
      h264Settings.setMode(this.streamWidth, this.streamHeight, this.streamFPS);
      this.oNetStream.videoStreamSettings = h264Settings;
      */

      console_log("Codec: " + this.oNetStream.videoStreamSettings.codec);
      /*
      console_log("H264 Profile: " + h264Settings.profile);
      console_log("H264 Level: " + h264Settings.level);
      */
      console_log("Video dimensions: " + getVideoWidth() + "x" + getVideoHeight());
      console_log("Resolution: " + this.streamWidth + "x" + this.streamHeight);
      console_log("Frame rate: " + this.streamFPS + "fps");
      console_log("Keyframe interval: " + this.keyFrameInterval);
      console_log("Bandwidth: " + this.bandwidth * 8 / 1024 + "Kbps");
      console_log("Quality: " + this.cameraQuality + "%");

      // start publishing the stream
      this.oNetStream.addEventListener(NetStatusEvent.NET_STATUS, eNetStatus, false, 0, true);
      console_log("Publishing to: " + getEdgecastStreamEndpoint());
      this.oNetStream.publish(getEdgecastStreamEndpoint());
      //console_log("Publishing to: " + this.sStreamName);
      //this.oNetStream.publish(this.sStreamName);

      /*
      // send metadata
      var metaData:Object = new Object();
      metaData.codec = this.oNetStream.videoStreamSettings.codec;
      metaData.profile = h264Settings.profile;
      metaData.level = h264Settings.level;
      metaData.fps = this.streamFPS;
      metaData.bandwith = this.bandwidth;
      metaData.width = this.streamWidth;
      metaData.height = this.streamHeight;
      metaData.keyFrameInterval = this.keyFrameInterval;
      this.oNetStream.send("@setDataFrame", "onMetaData", metaData);

      // listen for meta data
      this.oMetaData.onMetaData = eMetaDataReceived;
      this.oNetStream.client = this.oMetaData;
      */
    }

  	protected function eMetaDataReceived(oObject:Object):void {
      console_log("MetaData: " + oObject.toString());
    }

    public function onFCPublish(info:Object):void {
    	if (info.code == "NetStream.Publish.Start"){
        console_log("Ready to publish.")
        publish();
  		} else {
  			console_log("Error occurred publishing stream: " + info.code);
  		}
  	}

  	private function eNetStatus(oEvent1:NetStatusEvent):void {
  		switch (oEvent1.info.code) {
  			case "NetConnection.Connect.Success":
          console_log("Connected to the RTMP server.");
          //this.oConnection.call("FCPublish", null, this.sStreamName);
          publish();
  				break;

  			case "NetConnection.Connect.Closed":
  				console_log("Disconnected from the RTMP server.");
  				break;

        case "NetStream.Publish.Start":
          console_log("Publishing started.")
          break;

        case "NetStream.Failed":
          console_log("Couldn't stream to endpoint.");
          stop();
          break;

				default:
          console_log("NetStatusEvent: " + oEvent1.info.code);
					break;
			} // switch()
		} // function eNetStatus
  } // class recorder
} // package
