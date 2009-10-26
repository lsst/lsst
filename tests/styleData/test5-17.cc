// -*- LSST-C++ -*-
// 5-17  6,9     Avoid using 'break' and 'continue'. (used 'continue')
for (i = 0; i < 10; i++) {
    printf ("hello world %s %s %d\n", arg1, arg2, i);
    if (i) {
        continue;  // fail
    }
    if (i > 2) {
        break;  // fail
    }
}
c = 'q';
switch (c) {
  case 'v':
    verbose = 1;
    break;    // ok
  default:
    break;    // ok
}
