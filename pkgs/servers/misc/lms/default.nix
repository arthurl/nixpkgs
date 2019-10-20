{ stdenv
, fetchFromGitHub
, writeText
, autoreconfHook
, pkgconfig
, boost
, ffmpeg
, imagemagick
, libconfig
, taglib
, pstreams
, wt, useMinimalWt ? false
}:

let
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
in

stdenv.mkDerivation rec {
  pname = "lms";
  version = "3.1.0";

  src = fetchFromGitHub {
    owner = "epoupon";
    repo = pname;
    rev = "v${version}";
    sha256 = "1fi0af9nfz0jsmpqfmf471qjkfldf53gv3l7d1a8p1jzn4mqlla9";
  };

  enableParallelBuilding = true;

  nativeBuildInputs = [ autoreconfHook pkgconfig ];
  buildInputs = [
    boost.dev ffmpeg.dev imagemagick.dev libconfig taglib pstreams
    (if useMinimalWt then wt-minimal else wt)
  ];

  prePatch = ''
    substituteInPlace configure.ac \
      --replace 'AM_INIT_AUTOMAKE' 'AM_INIT_AUTOMAKE([subdir-objects])'
  '';

  patches = [
    # To be removed once LMS allows decoders to be externally set.
    (writeText "hardcode-ffmpeg-path.patch" ''
      diff --git a/src/av/AvTranscoder.cpp b/src/av/AvTranscoder.cpp
      index 5ddc943..50a20bb 100644
      --- a/src/av/AvTranscoder.cpp
      +++ b/src/av/AvTranscoder.cpp
      @@ -30,28 +30,13 @@ namespace Av {
       
       #define LMS_LOG_TRANSCODE(sev)	LMS_LOG(TRANSCODE, sev) << "[" << _id << "] - "
       
      -// TODO, parametrize?
      -static const std::vector<std::string> execNames =
      -{
      -	"avconv",
      -	"ffmpeg",
      -};
      -
       static std::filesystem::path	avConvPath = std::filesystem::path();
       static std::atomic<size_t>	globalId = {0};
       
       void
       Transcoder::init()
       {
      -	for (const std::string& execName : execNames)
      -	{
      -		const std::filesystem::path p {searchExecPath(execName)};
      -		if (!p.empty())
      -		{
      -			avConvPath = p;
      -			break;
      -		}
      -	}
      +	avConvPath = std::filesystem::path("${ffmpeg.bin}/bin/ffmpeg");
       
       	if (!avConvPath.empty())
       		LMS_LOG(TRANSCODE, INFO) << "Using transcoder " << avConvPath.string();
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
