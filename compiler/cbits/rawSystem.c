/* Grab rawSystem from the library sources iff we're bootstrapping with an
 * old version of GHC.
 */
#if defined(__GLASGOW_HASKELL__) && __GLASGOW_HASKELL__ < 601
#include "../../libraries/base/cbits/rawSystem.c"
#endif
