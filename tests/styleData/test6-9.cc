// -*- LSST-C++ -*-
// 6-9   3     Empty loops should be on one line.
for ( int i = 0; i < 2; ++i) {  // fail
}
for ( int i = 0; i < 2; ++i) {} // ok
