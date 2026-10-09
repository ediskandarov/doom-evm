// SPDX-License-Identifier: GPL-2.0-only
#include "zone-observe.h"
#define Z_Malloc(s,t,u) ZoneMallocObserved(ZONE_FILE,__func__,__LINE__,s,t,u)
#define Z_Free(p) ZoneFreeObserved(ZONE_FILE,__func__,__LINE__,p)
#define Z_FreeTags(l,h) ZoneTagsObserved(ZONE_FILE,__func__,__LINE__,l,h)
#undef Z_ChangeTag
#define Z_ChangeTag(p,t) ZoneTagObserved(ZONE_FILE,__func__,__LINE__,p,t)
