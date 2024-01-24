{ stdenv
, lib
, fetchFromGitHub
, writeText
, cmake
, pkg-config
, gtest
, boost
, zlib
, libarchive
, ffmpeg_4
, stb
, libconfig
, taglib
, wt, useMinimalWt ? false
}:

let
  ffmpeg = ffmpeg_4;

  # Wt with the minimum set of optional dependencies required for LMS
  wt-minimal = wt.override {
    # Docs not needed
    doxygen = null;
    # Graphics libraries not needed
    glew = null; libharu = null; pango = null; graphicsmagick = null;
    # LMS uses only sqlite
    firebird = null; libmysqlclient = null; postgresql = null;
    # Qt not used
    qt48Full = null;
  };

  wt-lms = if useMinimalWt then wt-minimal else wt;
in

stdenv.mkDerivation rec {
  pname = "lms";
  version = "3.47.0";

  src = fetchFromGitHub {
    owner = "epoupon";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-Wfas5Use71B7ZB3GUoxDUenGzlGO1riugBjhiqNbWRk=";
  };

  nativeBuildInputs = [ cmake pkg-config gtest ];
  buildInputs = [
    boost.dev zlib.dev libarchive.dev ffmpeg.dev stb libconfig taglib wt-lms
  ];
  cmakeFlags = [ "-DIMAGE_LIBRARY=STB" "-DCMAKE_BUILD_TYPE=Debug" ];

  patches = [
    (writeText "insert-dependency-paths.patch" ''
      diff --git a/src/libs/av/impl/Transcoder.cpp b/src/libs/av/impl/Transcoder.cpp
      index 074675bc..0787b30e 100644
      --- a/src/libs/av/impl/Transcoder.cpp
      +++ b/src/libs/av/impl/Transcoder.cpp
      @@ -52,7 +52,7 @@ namespace Av::Transcoding
       
           void Transcoder::init()
           {
      -        ffmpegPath = Service<IConfig>::get()->getPath("ffmpeg-file", "/usr/bin/ffmpeg");
      +        ffmpegPath = Service<IConfig>::get()->getPath("ffmpeg-file", "${ffmpeg.bin}/bin/ffmpeg");
               if (!std::filesystem::exists(ffmpegPath))
                   throw Exception{ "File '" + ffmpegPath.string() + "' does not exist!" };
           }
      diff --git a/src/lms/main.cpp b/src/lms/main.cpp
      index 696bdb94..da512694 100644
      --- a/src/lms/main.cpp
      +++ b/src/lms/main.cpp
      @@ -82,7 +82,7 @@ namespace
               const std::filesystem::path wtConfigPath{ Service<IConfig>::get()->getPath("working-dir") / "wt_config.xml" };
               const std::filesystem::path wtLogFilePath{ Service<IConfig>::get()->getPath("log-file", "/var/log/lms.log") };
               const std::filesystem::path wtAccessLogFilePath{ Service<IConfig>::get()->getPath("access-log-file", "/var/log/lms.access.log") };
      -        const std::filesystem::path wtResourcesPath{ Service<IConfig>::get()->getPath("wt-resources", "/usr/share/Wt/resources") };
      +        const std::filesystem::path wtResourcesPath{ Service<IConfig>::get()->getPath("wt-resources", "${wt-lms}/share/Wt/resources") };
       
               args.push_back(execPath);
               args.push_back("--config=" + wtConfigPath.string());
    '')
  ];

  meta = with lib; {
    description = "Lightweight / low memory music streaming server";
    longDescription = ''
      LMS is a self-hosted music streaming software: access your music
      collection from anywhere using a web interface or the subsonic API!
      Written in C++, it has a low memory footprint and even comes with a
      recommendation engine.
    '';
    homepage = https://github.com/epoupon/lms;
    downloadPage = "https://github.com/epoupon/lms";
    maintainers = with maintainers; [ arthur ];
    license = licenses.gpl3;
    platforms = platforms.all;
  };
}
