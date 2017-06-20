// -*- LSST-C++ -*-
// 5-33  5   Avoid goto statements
for (int i = 0; i < 10; ++i) {
    if (i > 5) {
        goto foo; // fail
    }
}

    
