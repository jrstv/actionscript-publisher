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
  	protected var sMediaServerURL:String = "rtmp://127.0.0.1:1935/live";
    protected var sStreamName:String = "foo";
  	protected var sStreamKey:String = "bar";
    protected var bandwidth:int = 2048;
  	protected var streamWidth:int = 720;
  	protected var streamHeight:int = 405;
    protected var streamFPS:int = 30;

  	protected var oConnection:NetConnection;
  	protected var oMetaData:Object = new Object();
  	protected var oNetStream:NetStream;

  	private var oVideo:Video;
  	private var oCamera:Camera;
  	private var oMicrophone:Microphone;
  	private var statusTxt:TextField = new TextField();

  	public function debug(string:String):void {
  		ExternalInterface.call("console.log", string);
  		this.statusTxt.text = string;
  	}

  	public function recorder() {
      // some media servers are dumb, so we need to catch a strange event
  		NetConnection.prototype.onBWDone = function(oObject1:Object):void {
        debug("onBWDone: " + oObject1.toString());
      }

      // EdgeCast's FMS usees the FCPublish protocol after connecting before streaming
      NetConnection.prototype.onFCPublish = onFCPublish;

      debug("recorder object has been created.");
      this.statusTxt.width = this.streamWidth;
      this.statusTxt.height = this.streamHeight;
      addChild(this.statusTxt);

      this.oVideo = new Video(this.streamWidth, this.streamHeight);
      this.addChild(this.oVideo);
      this.oConnection = new NetConnection();
      this.oConnection.addEventListener(NetStatusEvent.NET_STATUS, eNetStatus, false, 0, true);
      this.oConnection.objectEncoding = ObjectEncoding.AMF0;

      if (ExternalInterface.available) {
      	ExternalInterface.addCallback("trace", this.debug);
      	ExternalInterface.addCallback("setUrl", this.setUrl);
      	ExternalInterface.addCallback("getUrl", this.getUrl);
        ExternalInterface.addCallback("setStreamName", this.setStreamName);
        ExternalInterface.addCallback("getStreamName", this.getStreamName);
      	ExternalInterface.addCallback("setStreamKey", this.setStreamKey);
      	ExternalInterface.addCallback("getStreamKey", this.getStreamKey);
      	ExternalInterface.addCallback("setStreamWidth", this.setStreamWidth);
      	ExternalInterface.addCallback("getStreamWidth", this.getStreamWidth);
      	ExternalInterface.addCallback("setStreamHeight", this.setStreamHeight);
      	ExternalInterface.addCallback("getStreamHeight", this.getStreamHeight);
        ExternalInterface.addCallback("getStreamFPS", this.getStreamFPS);
        ExternalInterface.addCallback("setStreamFPS", this.setStreamFPS);
      	ExternalInterface.addCallback("getBandwidth", this.getBandwidth);
      	ExternalInterface.addCallback("setBandwidth", this.setBandwidth);
      	ExternalInterface.addCallback("connect", this.connect);
      	ExternalInterface.addCallback("disconnect", this.disconnect);
    	} else {
    		debug("External interface not available)");
    	}

  		// fix flash content resizing
  		import flash.display.*;
  		stage.align=StageAlign.TOP_LEFT;
  		stage.scaleMode=StageScaleMode.NO_SCALE;
  		stage.addEventListener(Event.RESIZE, updateSize);
  		stage.dispatchEvent(new Event(Event.RESIZE));
  	}

  	protected function updateSize(event:Event):void {
  		this.oVideo.width = stage.stageWidth;
  		this.oVideo.height = stage.stageHeight;
  		this.statusTxt.width = stage.stageWidth;
  		this.statusTxt.height = stage.stageHeight;
  	}

  	// External APIs -- invoked from JavaScript

  	public function setUrl(url:String):void {
  		this.sMediaServerURL = url;
      debug("URL: " + this.sMediaServerURL)
  	}

  	public function getUrl():String {
  		return this.sMediaServerURL;
  	}


    public function setStreamName(streamName:String):void {
      this.sStreamName = streamName;
      debug("Stream Name: " + this.sStreamName)
    }

    public function getStreamName():String {
      return this.sStreamName;
    }


  	public function setStreamKey(streamKey:String):void {
  		this.sStreamKey = streamKey;
      debug("Stream Key: " + this.sStreamKey)
  	}

  	public function getStreamKey():String {
  		return this.sStreamKey;
  	}


    public function setBandwidth(bandwidth:int):void {
      this.bandwidth = bandwidth;
      debug("Bandwidth: " + this.bandwidth + "bps")
    }

    public function getBandwidth():int {
      return this.bandwidth;
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


  	public function setStreamFPS(fps:int):void {
  		this.streamFPS = fps;
  	}

  	public function getStreamFPS():int {
  		return this.streamFPS;
  	}


  	public function connect():void {
  		debug("Connecting to url: " + this.sMediaServerURL);
  		this.oConnection.connect(this.sMediaServerURL);
  	}

  	public function disconnect():void {
  		this.oConnection.close();
  	}


  	protected function eMetaDataReceived(oObject:Object):void {
      debug("MetaData: " + oObject.toString());
    }

    public function onFCPublish(info:Object):void {
      // how to force proper codecs:
      //   http://www.adobe.com/devnet/adobe-media-server/articles/encoding-live-video-h264.html
    	debug("onFCPublish invoked: " + info.code);
    	if (info.code == "NetStream.Publish.Start"){
    		debug("Starting to Publish Stream");
    		this.oCamera = Camera.getCamera();
    		this.oCamera.setMode(this.streamWidth, this.streamHeight, this.streamFPS, true);
  			// bps, compression (0 = don't exceed bandwidth)
  			this.oCamera.setQuality(this.bandwidth, 0);
  			this.oCamera.setKeyFrameInterval(60);

  			debug("Container size " + this.width + "x" + this.height);
  			debug("Video size " + this.oVideo.width + "x" + this.oVideo.height);
  			debug("Camera size " + this.oCamera.width + "x" + this.oCamera.height);

  			this.oMicrophone = Microphone.getMicrophone();

  			this.oMicrophone.codec = SoundCodec.SPEEX;
  			this.oMicrophone.rate = 44;
  			this.oMicrophone.setSilenceLevel(0);
  			this.oMicrophone.encodeQuality = 5;
  			this.oMicrophone.framesPerPacket = 2;

  			// attach the camera to the video..
  			this.oVideo.attachCamera(this.oCamera);

  			this.oNetStream = new NetStream(this.oConnection);
  			// attach the camera and microphone to the stream..

  			this.oNetStream.attachCamera(this.oCamera);
  			this.oNetStream.attachAudio(this.oMicrophone);

  			var h264Settings:H264VideoStreamSettings = new H264VideoStreamSettings();
  			h264Settings.setProfileLevel(H264Profile.BASELINE, H264Level.LEVEL_3_1);

  			this.oNetStream.videoStreamSettings = h264Settings;

  			// start publishing the stream..
  			this.oNetStream.addEventListener(NetStatusEvent.NET_STATUS, eNetStatus, false, 0, true);
  			debug("publishing to: " + this.sStreamName + "?" + this.sStreamKey);
  			this.oNetStream.publish(this.sStreamName + "?" + this.sStreamKey);

  			// send metadata
  			var metaData:Object = new Object();

  			metaData.codec = this.oNetStream.videoStreamSettings.codec;
  			metaData.profile = h264Settings.profile;
  			metaData.level = h264Settings.level;
  			metaData.fps = this.oCamera.fps;
  			metaData.bandwith = this.oCamera.bandwidth;
  			metaData.height = this.oCamera.height;
  			metaData.width = this.oCamera.width;
  			metaData.keyFrameInterval = this.oCamera.keyFrameInterval;

  			this.oNetStream.send( "@setDataFrame", "onMetaData", metaData);

  			// listen for meta data..
  			this.oMetaData.onMetaData = eMetaDataReceived;
  			this.oNetStream.client = this.oMetaData;
  			debug("Started Stream");
  		} else {
  			debug("Error Occurred Publishing Stream");
  		}
  	}

  	private function eNetStatus(oEvent1:NetStatusEvent):void {
  		debug("NetStatusEvent: " + oEvent1.info.code); // debug trace..

  		switch (oEvent1.info.code) {
  			case "NetConnection.Connect.Success":
  			  this.oConnection.call("FCPublish", null, this.sStreamName);
  				debug("Connected to the RTMP server."); // debug trace..
  				break;

  			case "NetConnection.Connect.Closed":
  				debug("Disconnected from the RTMP server."); // debug trace..
  				break;

				case "NetConnection.Connect.Closed":
					break;

				default:
					debug(oEvent1.info.code);
					debug(oEvent1.info.description);
					break;
			} // switch()
		} // function eNetStatus
  } // class recorder
} // package
