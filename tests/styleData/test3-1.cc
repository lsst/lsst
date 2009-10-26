// -*- LSST-C++ -*-
// 3-1 3,5 "User defined types must be mixed-case, starting with uppercase.";
typedef double myDouble; // fail
typedef double MyDouble; // pass
typedef double badDoub;  // fail
