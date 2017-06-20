// -*- LSST-C++ -*-
// 3-24   3    Boolean variables must begin with 'is' or 'has'.
bool const badName = true; // fail
bool isGood = true;        // ok
bool hasGoodness = true;   // ok
