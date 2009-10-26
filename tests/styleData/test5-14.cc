// -*- LSST-C++ -*-
// 5-14   4    Put only loop control in parentheses of for() statement
int j = 0;
for (int i = 0; i < 10; ++i, ++j) {
    printf("%d %d\n", i, j);
}
