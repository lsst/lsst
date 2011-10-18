// -*- LSST-C++ -*-
// 4-7    7    Avoid special characters.
// 5-22   4   No executible (assignments) in conditionals
while ( (c = getopt(argc, argv, "v")) != -1 ) {
        switch (c) {
          case 'v':
       	verbose = 1;  // fail (contains a tab)
            break;
          default:
            break;
        }
    }


    
