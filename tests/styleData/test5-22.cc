// -*- LSST-C++ -*-
// 5-22   6    No executible (assignments) in conditional statments.
if (j == 6) {
    j += 1;
}
if ( j = getNewJ(); ) { // fail
    j += 1;
}

