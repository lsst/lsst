// -*- LSST-C++ -*-
// 4-4a  11,17    Define all non-templated functions in .cc file
// 4-9 2           Prevent multiple header inclusion.
template<MyType>
MyType okFunc(MyType const &a);

float badArgs(float a, MyType const &foo) {
    return a*foo;
}

float fooFoo(float a,
             float b, float c,
             float d) {
    return a + b + c + d;
}

float badFunc(float a) {              // fail
    float b = a*a;
    int j = 0;
    for (int i = 0; i < 10; ++i) {
        b += i*j;
    }

    // good loop
    for (int i = 0; i < 10; ++i) {
        b += i*j;
        j++;
        if (j == 6) {
            j += 1;
        }
    }

    return b;
}

