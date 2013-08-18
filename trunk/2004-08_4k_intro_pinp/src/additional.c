#include "gl.h"
#include "glut.h"
#include <math.h>

#define SCREEN_W 720
#define SCREEN_H 540

extern float func_moo(float);

float sum, X;

int lyapunov(void *params)
{
  float framebuffer[SCREEN_W*SCREEN_H];
  char* sequence = "ABBAABBAABAB";
  int iterations = 20;
  int iterationcnt = 0;

  float R;
  float sum2;
  float largest=0;
  float seed = 0.4999999; //0.5 on hyvä pop. seed
  
  float xscale = 40.0; //eli ruutu menee ikkunaan 2,2
  float yscale = 40.0;
  float x=2;
  float y=2;
  float zoom=2.5;

//  float a; //siihen vitun mandeliin
//  float b;
//  float z1;
//  float z2;

  int i,j,k;

  for(i=0; i<SCREEN_H; i++) {
    for(j=0; j<SCREEN_W; j++) {
/*      for(k=0; k<iterations; k++) {
	if(sequence[iterations%seqlen-1] == 'A') //jakojäännöksellä katsotaan missä kohtaa sekvenssiä ollaan menossa -> A ottaa x-akselilta ja B y-akselilta
//	if(1)
	  R = (float)(i-320)/xscale;
	else 
	  R = (float)(j-240)/yscale;
	X = R*X*(1-X);
      }
//      X = X/(float)(iterations);*/

      iterationcnt = 0;

      sum = 1;
      X = seed;

      for(k=0; k<iterations; k++) {
	if(sequence[iterationcnt] == 'A')
//	if(1)
	  R = x+(float)(j-SCREEN_W/2)/(xscale*zoom);
	else
	  R = y+(float)(i-SCREEN_H/2)/(yscale*zoom);
	
	iterationcnt++;
	if(iterationcnt>=12) iterationcnt=0;
	
	X = R*X*(1-X);
	sum2 = R-2*R*X;
	if(sum2<0) sum = sum * (-sum2); //vitun abs() tehtävä näin, entajuu(tm)
	else sum = sum*sum2;
	//sum = sum * abs(R-2*R*X);
      }
      sum = log(sum)/((float)iterations);
      if(sum<0.0) framebuffer[i*SCREEN_W+j] = -sum; //hupaisaa väriä
      else framebuffer[i*SCREEN_W+j] = 0;

//      if(-sum>largest) largest=-sum;


// Joo se piirtää mandelin, oli vain vittu vieköön pakko tarkistaa että JOKIN toimii
/*
      z1=a=(float)(i-320)/xscale;
      z2=b=(float)(j-240)/yscale;
      for(k=0; k<iterations; k++) {
	if(abs(z1*z1+z2*z2)>4.0) break;
	a=z1*z1-z2*z2+(float)(i-320)/xscale;
	b=2*z1*z2+(float)(j-240)/yscale;
	z1=a;
	z2=b;
      }
      framebuffer[i*480+j]=(float)k/(float)iterations;
*/
    }
  }

  glLoadIdentity();
  glBegin(GL_POINTS);
  for(i=0; i<SCREEN_H; i++) {
    for(j=0; j<SCREEN_W; j++) {
//      glTranslatef((float)(i-320), (float)(j-240), -700);
//      glColor3f(framebuffer[i*480+j]/largest,framebuffer[i*480+j]/largest,framebuffer[i*480+j]/largest);
      glColor3f(framebuffer[i*SCREEN_W+j],framebuffer[i*SCREEN_W+j],framebuffer[i*SCREEN_W+j]);
//    glColor3f(1.0,0,0);
//      glutSolidSphere(5.0, 3, 3);
      glVertex3f((float)(j), (float)(i), -SCREEN_W);
    }
  }
  glEnd();

  return 0;
}

