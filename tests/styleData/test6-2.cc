// -*- LSST-C++ -*-
// 6-2   6     Use 4-space indentation
// 5-22  9     No executible (assignments) in conditional statments.
while (1) {
    float i = 1.0;
     int j = 1;  // fail
    float x = i*j;
}
while ( (c = getopt(argc, argv, "v")) != -1 ) {
    switch (c) {
      case 'v':  // ok
        verbose = 1;
        break;
      default:   // ok
        break;
    }
}

float myFunction(float x,
                 float y) {
    return x*y;
}

for (int i = getI();
     i < 10; ++i) {
    return i*i;
}
