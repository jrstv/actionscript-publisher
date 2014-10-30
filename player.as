/**
 *
 * SIMPLE FLV VIDEO PLAYER AS3
 *
 * Provides video player and timer reference for possible additional external Javascript API calls
 *
 * Version 0.1
 *
 * Author : Mark Rushton
 *
 */


package
{

  import flash.display.Sprite;
  import flash.events.Event;
  import flash.events.NetStatusEvent;
  import flash.events.TimerEvent;
  import flash.external.ExternalInterface;
  import flash.media.Video;
  import flash.media.SoundTransform;
  import flash.net.NetConnection;
  import flash.net.NetStream;
  import flash.net.URLLoader;
  import flash.net.URLRequest;
  import flash.text.TextField;
  import flash.text.TextFieldAutoSize;
  import flash.text.TextFormat;
  import flash.utils.Timer;

  public class player extends Sprite
  {

    private var _video:Video;
    private var _stream:NetStream;
    private var connection:NetConnection;
    private var _playbackTime:TextField;
    private var _duration:uint;
    private var _timer:Timer;
    protected var options:Object = {
      serverURL: null
    , streamName: null
    , jsLogFunction: "console.log"
    , jsEmitFunction: null
    }


    public function player()
    {
      //_duration = 0;

      //_playbackTime = new TextField();
      //_playbackTime.autoSize = TextFieldAutoSize.LEFT;
      //_playbackTime.y = 20;
      //_playbackTime.x = 20;
      //_playbackTime.text = "Buffering _";
      //_timer =new Timer(1000);
      //_timer.addEventListener(TimerEvent.TIMER, onTimer);
      //_timer.start();

      if (ExternalInterface.available) {
        ExternalInterface.addCallback("setOptions", this.setOptions);
        ExternalInterface.addCallback("play", this.play);
        ExternalInterface.addCallback("stop", this.stop);
      } else {
        log("External interface not available.");
      }
    }

    // setOptions from publisher
    public function setOptions(options:Object):void {
      log("Received options:", options)
      for(var p:String in options) {
        if (options[p] != null) {
          this.options[p] = options[p];
        }
      }
    }

    // log to the JavaScript console
    public function log(... arguments):void {
      if (options.jsLogFunction == null){
        return;
      }
      var applyArgs:Array = [options.jsLogFunction, "player:"].concat(arguments);
      ExternalInterface.call.apply(this, applyArgs);
    }

    // log to the JavaScript console
    public function emit(emitObject:Object):void {
      if (options.jsEmitFunction == null){
        return;
      }
      ExternalInterface.call.apply(this, [options.jsEmitFunction, emitObject]);
    }

    public function stop():void{
        log("stop not implemented.");
    }

    public function play():void{

      try {
        log("connecting to server:", this.options.serverURL);
        log("connecting to stream:", this.options.streamName);
        log("full url: ", this.options.serverURL+'/'+this.options.streamName);
        this.connection = new NetConnection();
        connection.connect(this.options.serverURL);
        connection.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);


        //addChild(_playbackTime);
      } catch (err:Error) {
        log("ERROR:", err);
        emit({kind: "error", message: err});
      }

    }

    private function playStream():void{
      try {

        _stream = new NetStream(connection);
        _stream.play(this.options.streamName);

        var videoVolumeTransform:SoundTransform = new SoundTransform();
        emit({kind: 'status', message: "setting volume to 0"});
        videoVolumeTransform.volume = 0;
        _stream.soundTransform = videoVolumeTransform;

        //_stream.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
        _video = new Video();
        var client:Object = new Object();
        client.onMetaData = onMetaData;
        client.onCuePoint = onCuePoint;
        client.onTextData = onTextData;
        _stream.client = client;
        _video.attachNetStream(_stream);
        addChild(_video);
        emit({kind: 'status', message: "added video"});
      } catch (err:Error) {
        log("ERROR:", err);
        emit({kind: "error", message: err});
      }

    }

    private function onMetaData(data:Object):void{
      emit({kind: "status", event: 'onMetaData', data: data});
      if (data.width && data.height){

      }

        var _stageW:int = stage.stageWidth;
        var _stageH:int = stage.stageHeight;

        var _videoW:int;
        var _videoH:int;
        var _aspectH:int;

        var Aspect_num:Number; //should be an "int" but that gives blank picture with sound
        Aspect_num = data.width / data.height;

        //Aspect ratio calculated here..
        _videoW = _stageW;
        _videoH = _videoW / Aspect_num;
        _aspectH = (_stageH - _videoH) / 2;

        _video.x = 0;
        _video.y = _aspectH;
        _video.width = _videoW;
        _video.height = _videoH;

      //_duration = data.duration;

    }

    private function onTextData(data:Object):void {
      emit({kind: "status", event: "onTextData", data: data})
    }
    private function onCuePoint(data:Object):void {
      emit({kind: "status", event: "onCuePoint", data: data})
    }
    /*
    private function onNetStatus(e:NetStatusEvent):void{

      _video.width = _video.videoWidth;
      _video.height = _video.videoHeight;

    }*/

    // respond to network status events
    private function onNetStatus(event1:NetStatusEvent):void {
      switch (event1.info.code) {
        case "NetConnection.Connect.Success":
          emit({kind: "connect", code: 200, message: "Connected to the RTMP server."});
          playStream();
          break;
        case "NetConnection.Connect.Failed":
          //isDisconnected();
          emit({kind: "disconnect", code: 501, message: "Couldn't connect to the RTMP server."});
          break;

        case "NetConnection.Connect.Closed":
          //isDisconnected();
          emit({kind: "disconnect", code: 502, message: "Disconnected from the RTMP server."});
          break;

        case "NetStream.Publish.Start":
          //this._isPublishing = true;
          // send metadata immediately after Publish.Start
          // https://forums.adobe.com/thread/629972?tstart=0
          //sendMetaData();
          emit({kind: "connect", code: 201, message: "Publishing started."})
          break;

        case "NetStream.Failed":
          //stop();
          emit({kind: "error", code: 503, message: "Couldn't stream to endpoint (fail)."});
          break;

        case "NetStream.Publish.Denied":
          //stop();
          emit({kind: "error", code: 504, message: "Couldn't stream to endpoint (deny)."});
          break;

        default:
          log("NetStatusEvent: " + event1.info.code);
          break;
      }
    }

    /*private function onTimer(t:TimerEvent){

      if(_duration > 0 && _stream.time > 0){
        _playbackTime.text = Math.round(_stream.time) + " / " + Math.round(_duration);
      }

    }*/

  }
}