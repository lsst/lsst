// -*- LSST-C++ -*-
// 6-21b  3,6    Left-align nested namespaces.
namespace foo { namespace bar {  // fail
        
namespace foo {
    namespace bar {   // fail


