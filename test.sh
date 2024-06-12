#!/bin/sh
# A little script to create all 5 kinds of word graph data sets:
#   m)aybe-reciprocal,maybe-defd, r)eciprocized, d)efined, u)ndefined, a)any
set -e; umask 022
if [ $# -lt 1 ]; then cat <<EOF
Usage:
    $0 { fetch | demo | ...moby/words.txt }
demo is a mode that uses a very tiny example to show all the various cases.
EOF
  exit 1
fi
case "$1" in
    fetch) wget https://github.com/words/moby/raw/master/words.txt
           set words.txt ;;
    demo)  cat >demo.txt <<EOF
a,b,c
b,a,c
c,a,d,e
d,e
EOF
           set demo.txt ;;
esac
[ -e $HOME/.config/thes ] && {
    echo "Not clobbering existing $HOME/.config/thes"
    exit 2
}
mkdir -p $HOME/.config/thes
cat > $HOME/.config/thes/config <<EOF
base  = "$HOME/.config/thes/m"   # m for Moby
# base  = "$HOME/.config/thes/r"
# base  = "$HOME/.config/thes/d"
# base  = "$HOME/.config/thes/u"
# base  = "$HOME/.config/thes/a"
limit  = 150
types  = xRef
EOF
thes -i "$1" -b $HOME/.config/thes/m </dev/null # /dev/null blocks server REPL

nim c -d=danger -o=symmSyn util/symmSyn.nim
for kind in r d u a; do
  ./symmSyn -a $kind < "$1" > adj.txt
  thes -i adj.txt -b $HOME/.config/thes/$kind < /dev/null
  rm -f adj.txt
done
rm -f symmSyn
[ "$1" = "demo.txt" ] && {
  echo "Thesaurus is:"; cat demo.txt | sed 's/^/  /g'
  echo "Synonyms for 'c' in maybe tables:"
  thes -b $HOME/.config/thes/m c
  echo "Synonyms for 'c' in reciprocal-symmetrized tables:"
  thes -b $HOME/.config/thes/r c
  echo "Synonyms for 'c' in defined-symmetrized tables:"
  thes -b $HOME/.config/thes/d c
  echo "Synonyms for 'c' in undefined-symmetrized tables:"
  thes -b $HOME/.config/thes/u c
  echo "Synonyms for 'c' in any ref/completed graph symmetrization:"
  thes -b $HOME/.config/thes/a c
  rm -f demo.txt
}
#This with "demo" as it only argument should print:
#Thesaurus is:
#  a,b,c
#  b,a,c
#  c,a,d,e
#  d,e
#Synonyms for 'c' in maybe tables:
#a                                       d                                     e
#Synonyms for 'c' in reciprocal-symmetrized tables:
#a
#Synonyms for 'c' in defined-symmetrized tables:
#a                                       b                                     d
#Synonyms for 'c' in undefined-symmetrized tables:
#a                                                                             e
#Synonyms for 'c' in any ref/completed graph symmetrization:
#a                          b                         d                        e
