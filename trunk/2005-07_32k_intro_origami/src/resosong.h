#ifndef __RESOSONG_H__
#define __RESOSONG_H__

unsigned char resoorder[] = {
   0, 0, 0, 0, // part1 
   0, 0, 0, 0, 
   1, 1, 1, 2, 
   1, 1, 1, 2, 

     0, 0, 0, 0, // part2
     3, 3, 3, 3,
     3, 3, 3, 3,
     3, 3, 3, 3,
     4, 4, 5, 5, // a# g#
     
     0, 0, 0, 0, // part 3
     0, 0, 0, 0,
     7, 7, 7, 7,
     6, 6, 6, 6,

     8, 0, 0, 0,// hilijaa stna
     0, 0, 0, 0,
     0, 0, 0, 0,

     END
};

unsigned char resopatterns[] = {

    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,

    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,

    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,

    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,

    // 1
    C_5, 24,
    OFF, 24,
    H_4, 32,
    OFF, 32,
    G_4, 48,
    OFF, 48,
    A_4, 64,
    OFF, 64,

    E_4, 80,
    OFF, 80,
    H_4, 90,
    OFF, 90,
    A_4, 110,
    OFF, 110,
    D_5, 150,
    OFF, 150,

    C_5, 24,
    OFF, 24,
    G_4, 32,
    OFF, 32,
    C_5, 48,
    OFF, 48,
    E_5, 64,
    OFF, 64,

    G_4, 80,
    OFF, 80,
    E_5, 90,
    OFF, 90,
    D_5, 110,
    OFF, 110,
    H_4, 150,
    OFF, 150,

    // 2
    As4, 180,
    OFF, 180,
    G_4, 140,
    OFF, 140,
    As4, 120,
    OFF, 120,
    Ds5, 100,
    OFF, 100,

    G_4, 90,
    OFF, 90,
    Ds5, 80,
    OFF, 80,
    D_5, 70, 
    OFF, 70,
    As4, 60,
    OFF, 60, 

    As4, 50,
    OFF, 50,
    F_4, 40,
    OFF, 40,
    As4, 35,
    OFF, 35,
    Ds5, 32,
    OFF, 32,

    F_4, 40,
    OFF, 50,
    Ds5, 60,
    OFF, 70,
    D_5, 80,
    OFF, 90,
    As5, 100,
    OFF, 100,

    // 3
    OFF, 180,
    OFF, 180,
    F_4, 140,
    OFF, 140,
    F_5, 30,
    F_5, 50,
    F_5, 70,
    F_5, 100,

    OFF, 90,
    OFF, 90,
    C_6, 80,
    OFF, 80,
    C_4, 140,
    C_4, 120,
    C_4, 100,
    C_4, 80, 

    C_5, 60,
    C_4, 40,
    C_5, 30,
    OFF, 80,
    OFF, 70, 
    Gs6, 70,
    Gs6, 60,
    OFF, 60, 

    Gs5, 90,
    Gs5, 150,
    Gs5, 40,
    Gs5, 60,
    Gs5, 100,
    Gs6, 70,
    Gs4, 60,
    OFF, 60, 

    // 4
    OFF, 180,
    OFF, 180,
    As4, 250,
    OFF, 140,
    As5, 35,
    As5, 50,
    OFF, 70,
    As5, 100,

    OFF, 90,
    OFF, 90,
    As4, 120,
    OFF, 80,
    As4, 140,
    As4, 30,
    As5, 100,
    A_5, 80, 

    F_5, 160,
    OFF, 40,
    F_5, 100,
    OFF, 80,
    OFF, 70, 
    OFF, 70,
    OFF, 60,
    OFF, 60, 

    OFF, 40,
    OFF, 30,
    OFF, 40,
    OFF, 60,
    OFF, 100,
    OFF, 70,
    OFF, 60,
    OFF, 160, 

    // 5
    OFF, 180,
    OFF, 180,
    Gs4, 250,
    OFF, 140,
    Gs3, 35,
    Gs3, 50,
    OFF, 70,
    Gs5, 100,

    OFF, 90,
    OFF, 90,
    Gs4, 120,
    OFF, 80,
    Gs4, 140,
    Gs4, 120,
    F_4, 100,
    Gs5, 80, 

    Ds4, 160,
    OFF, 40,
    Ds4, 100,
    OFF, 80,
    OFF, 70, 
    OFF, 70,
    OFF, 60,
    OFF, 60, 

    OFF, 90,
    OFF, 50,
    OFF, 40,
    OFF, 60,
    OFF, 100,
    OFF, 70,
    OFF, 60,
    OFF, 60, 

    // 6
    OFF, 128,
    OFF, 28,
    A_5, 28,
    A_4, 28,
    OFF, 28,
    OFF, 8,
    A_5, 38,
    A_4, 38,

    OFF, 38,
    OFF, 38,
    A_5, 48 ,
    A_4, 48,
    OFF, 48 ,
    OFF, 48,
    A_5, 58 ,
    A_4, 58,

    OFF, 68 ,
    OFF, 68,
    A_5, 68 ,
    A_4, 68,
    OFF, 78 ,
    OFF, 78,
    A_5, 78 ,
    A_4, 78,

    OFF, 88 ,
    OFF, 88,
    A_5, 88 ,
    A_4, 88,
    OFF, 98 ,
    OFF, 98,
    A_5, 98 ,
    A_4, 89,

    // 7
    OFF, 128,
    OFF, 28,
    Gs5, 28,
    Gs4, 28,
    OFF, 28,
    OFF, 8,
    Gs5, 38,
    Gs4, 38,

    OFF, 38,
    OFF, 38,
    Gs5, 48 ,
    Gs4, 48,
    OFF, 48 ,
    OFF, 48,
    Gs5, 58 ,
    Gs4, 58,

    OFF, 68 ,
    OFF, 68,
    Gs5, 68 ,
    Gs4, 68,
    OFF, 78 ,
    OFF, 78,
    Gs5, 78 ,
    Gs4, 78,

    OFF, 88 ,
    OFF, 88,
    Gs5, 88 ,
    Gs4, 88,
    OFF, 98 ,
    OFF, 98,
    Gs5, 98 ,
    Gs4, 89,

    //8
    OFF, 128,
    A_3, 128,
    A_3, 30 ,
    A_4, 40 ,
    A_3, 100,
    A_4, 80 ,
    A_3, 150,
    A_3, 30 ,

    A_4, 60 ,
    A_3, 128,
    A_3, 25 ,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,

    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,

    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,
    OFF, 128,

};

#endif
