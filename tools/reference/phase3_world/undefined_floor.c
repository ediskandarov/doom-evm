/* SPDX-License-Identifier: GPL-2.0-only
 * Audit unsupported original EV_DoFloor(donutRaise), not a gameplay fixture. */
int main(void){
    int32_t a[8]={4,donutRaise,0,0,0,0,1,0};setup(a);
    EV_DoFloor(&lines[0],donutRaise);P_RunThinkers();return 0;
}
