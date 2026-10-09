// SPDX-License-Identifier: GPL-2.0-only
void *ZoneMallocObserved(const char *,const char *,int,int,int,void *);
void ZoneFreeObserved(const char *,const char *,int,void *);
void ZoneTagsObserved(const char *,const char *,int,int,int);
void ZoneTagObserved(const char *,const char *,int,void *,int);
void ZoneFragmentObserved(void *);
void ZoneFreedObserved(void *);
void ZoneStage(const char *);
int ZoneOffset(void *);
void ZoneTextureLayout(void *);
