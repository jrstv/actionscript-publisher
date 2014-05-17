# ActionScript Publisher

This is a Flash app that allows live-streaming via RTMP from a web browser.

It depends on an [EC2 Image](#ec2-image) with the [nginx-rtmp-module][nginx-rtmp-module] installed, along with a custom `ffmpeg` with the "non-free" `x264` and `libfdk_aac` linked-in.

## Notes

For ease of debugging, it uses the `flash.external.ExternalInterface` class do push all of its logging into JavaScript via console.log.

## EC2 Image

### How to Build

- [Install nginx-rtmp-module][install-nginx-rtmp-module]
- Install libspeex-dev: `sudo apt-get install libspeex-dev`
- [Custom build ffmpeg from source][custom-build-ffmpeg]

### Nginx Config

    error_log /var/log/nginx/error.log;

    rtmp {
      server {

        listen 1935;
        chunk_size 4096;

        application live {
          live on;

          #record all;
          #record_path /tmp;
          #record_suffix -%d-%b-%y-%T.flv;

          exec /home/ubuntu/bin/ffmpeg -i rtmp://localhost:1935/${app}/${name} -c:v libx264 -b:v 2000k -c:a libfdk_aac -profile:a aac_he -f flv rtmp://stream.lax.cine.io/20C45E/stages/${name}?${args} 2>>/tmp/ffmpeg.log;
        }
      }
    }

## Acknowlegements

This code is based on the work done by [Davide Bertola](http://dadeb.it/) in the [webproducer](https://github.com/davibe/webproducer) project.


<!-- external links -->

[nginx-rtmp-module]:https://github.com/arut/nginx-rtmp-module
[install-nginx-rtmp-module]:https://github.com/arut/nginx-rtmp-module/wiki/Installing-on-Ubuntu-using-PPAs
[custom-build-ffmpeg]:https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu