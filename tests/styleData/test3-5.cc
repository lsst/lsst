// -*- LSST-C++ -*-
// 3-5   3,5    typedef ends in T, _t, Type, etc
typedef float MyFloatType; //fail
typedef double MyDoub;     // pass
typedef int MyIntT;        // fail
typedef int MyInt;         // pass
