{ stdenv
, fetchFromGitHub
, writeText
, cmake
, pkgconfig
, boost
, ffmpeg_4
, graphicsmagick
, libconfig
, taglib
, pstreams
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
  version = "3.22.0";

  src = fetchFromGitHub {
    owner = "epoupon";
    repo = pname;
    rev = "v${version}";
    sha256 = "1idky4wvkg66d4aab47pc6sv3lm07lzn2n1lic0hkhdaiisaq37n";
  };

  enableParallelBuilding = true;

  nativeBuildInputs = [ cmake pkgconfig ];
  buildInputs = [
    boost.dev ffmpeg.dev graphicsmagick libconfig taglib pstreams wt-lms
  ];

  patches = [
    (writeText "hardcode-dependency-paths.patch" ''
      diff --git a/src/libs/av/impl/AvTranscoder.cpp b/src/libs/av/impl/AvTranscoder.cpp
      index 574f829..fe557cb 100644
      --- a/src/libs/av/impl/AvTranscoder.cpp
      +++ b/src/libs/av/impl/AvTranscoder.cpp
      @@ -38,7 +38,7 @@ static std::filesystem::path	ffmpegPath;
       void
       Transcoder::init()
       {
      -	ffmpegPath = Service<IConfig>::get()->getPath("ffmpeg-file", "/usr/bin/ffmpeg");
      +	ffmpegPath = Service<IConfig>::get()->getPath("ffmpeg-file", "${ffmpeg.bin}/bin/ffmpeg");
       	if (!std::filesystem::exists(ffmpegPath))
       		throw LmsException {"File '" + ffmpegPath.string() + "' does not exist!"};
       }
      diff --git a/src/lms/main.cpp b/src/lms/main.cpp
      index 202b71d..d07201e 100644
      --- a/src/lms/main.cpp
      +++ b/src/lms/main.cpp
      @@ -48,7 +48,7 @@ generateWtConfig(std::string execPath)
       	const std::filesystem::path wtConfigPath {Service<IConfig>::get()->getPath("working-dir") / "wt_config.xml"};
       	const std::filesystem::path wtLogFilePath {Service<IConfig>::get()->getPath("log-file", "/var/log/lms.log")};
       	const std::filesystem::path wtAccessLogFilePath {Service<IConfig>::get()->getPath("access-log-file", "/var/log/lms.access.log")};
      -	const std::filesystem::path wtResourcesPath {Service<IConfig>::get()->getPath("wt-resources", "/usr/share/Wt/resources")};
      +	const std::filesystem::path wtResourcesPath {Service<IConfig>::get()->getPath("wt-resources", "${wt-lms}/share/Wt/resources")};
       	const unsigned long configHttpServerThreadCount {Service<IConfig>::get()->getULong("http-server-thread-count", 0)};
       
       	args.push_back(execPath);
    '')
  ];

  meta = with stdenv.lib; {
    description = "Lightweight, self-hosted, music streaming server.";
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
