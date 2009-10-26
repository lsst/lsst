// -*- LSST-C++ -*-
// 4-11 12 #includes should preceed all other statments.
#include <stdlib.h>
#include <stdio.h>
#include <getopt.h>

template<typename GoodTypeT>                   // should pass 3-7
template<typename GoodOne, typename GoodTwo>   // should pass 3-7

using namespace std;

#include <cmath>       // fail

int fooAbcBar = 5; // pass 3-8

