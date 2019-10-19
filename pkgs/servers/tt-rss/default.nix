{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "tt-rss";
  version = "2019-05-31";
  rev = "48c2db6ef1c48dec311fca363b09d99727205b96";

  src = fetchurl {
    url = "https://git.tt-rss.org/git/tt-rss/archive/${rev}.tar.gz";
    sha256 = "1vv7wccll5gqzvy7frq4v6apwqfkafdwwjfhaw8pz37dnn3cbng4";
  };

  installPhase = ''
    mkdir $out
    cp -ra * $out/
  '';

  meta = with stdenv.lib; {
    description = "Web-based news feed (RSS/Atom) aggregator";
    license = licenses.gpl2Plus;
    homepage = https://tt-rss.org;
    maintainers = with maintainers; [ globin zohl ];
    platforms = platforms.all;
  };
}
