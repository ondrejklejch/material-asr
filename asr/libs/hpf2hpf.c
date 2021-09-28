#include "stdio.h"
#include "stdlib.h"
#include "float.h"

#define TRUE 1
#define FALSE 0

/*
In most cases must swap byte order in the header
*/
void SwapInt(int *p)
{
   char temp,*q;
   
   q = (char*) p;
   temp = *q; *q = *(q+3); *(q+3) = temp;
   temp = *(q+1); *(q+1) = *(q+2); *(q+2) = temp;
}
void SwapShort(short *p)
{
   char temp,*q;
   
   q = (char*) p;
   temp = *q; *q = *(q+1); *(q+1) = temp;
}

void SwapFloat(float *x)
{
  int j,n=1;
  float *p;

  for(p=x,j=0;j<n;p++,j++)
    SwapInt((int*)p);
}

unsigned int UpdateCRCC(void *data,int n,int s,int bSwap,unsigned int crcc)
{
   char *ptr = (char *) data;
   int i;
   unsigned short s1,s2;

   for (i=0;i<n;i++) {
      switch(s) {
      case sizeof(int):
         s1=*(short*)ptr; ptr+=sizeof(short);
         s2=*(short*)ptr; ptr+=sizeof(short);
         if (bSwap) crcc=(crcc*65536+s2)%36897,crcc=(crcc*65536+s1)%36897;
         else crcc=(crcc*65536+s1)%36897,crcc=(crcc*65536+s2)%36897;
         break;
      case sizeof(short):
         s1=*(short*)ptr; ptr+=sizeof(short);
         crcc=(crcc*65536+s1)%36897;
         break;
      default:
         break;
      }
   }
   return(crcc);
}

int main(int argc, char *argv[])
{
  /*check sizes of int and short: just in case*/
  if(sizeof(int)!=4||sizeof(short)!=2){
    printf("Size of int and short must be 4 and 2 bytes.\n");
    printf("Run on another machine."); exit(1);
  }

  if((argc!=4)&&(argc!=5)){
    printf("Usage: %s htk-file-in add-file-in [# cols] htk-file-out\n",argv[0]); exit(1);
  }

  FILE *file_in1, *file_in2, *file_out1;
  int c=0,ncol=1;
  
  /*open first input file*/
  if((file_in1=fopen(argv[++c],"rb"))==NULL){
    printf("Failed to open %s\n",argv[c]); exit(1);
  }

  /*open second input file*/
  if((file_in2=fopen(argv[++c],"r"))==NULL){
    printf("Failed to open %s\n",argv[2]); exit(1);
  }
  
  /*# columns is set explicitly so read it*/
  if(argc==5){
    if((ncol=atoi(argv[++c]))<1){
      printf("Illegal num col: %s\n",argv[c]); exit(1);
    }
  }

  /*open first output file*/
  if((file_out1=fopen(argv[++c],"wb"))==NULL){
    printf("Failed to open %s\n",argv[c]);
    exit(1);
  }

  /*read HTK header: see HTK book*/

  /*4-byte entries first*/
  int nSamples,sampPeriod,i;
  if(fread(&i,sizeof(int),1,file_in1)!=1){
    printf("Failed to read number of samples\n");
    exit(1);
  }
  SwapInt(&i); nSamples=i;
  /*printf("Num samples %d\n",nSamples);*/

  if(fread(&i,sizeof(int),1,file_in1)!=1){
    printf("Failed to read sampling period\n");
    exit(1);
  }
  SwapInt(&i); sampPeriod=i;
  /*printf("Sampling period %d\n",sampPeriod);*/

  /*2-byte entries last*/
  short sampSize,parmKind,s;
  if(fread(&s,sizeof(short),1,file_in1)!=1){
    printf("Failed to read sample size\n");
    exit(1);
  }
  SwapShort(&s); sampSize=s;
  /*printf("Sample size %d\n",(int)sampSize);*/

  if(fread(&s,sizeof(short),1,file_in1)!=1){
    printf("Failed to read parameter kind\n");
    exit(1);
  }
  SwapShort(&s); parmKind=s;
  /*printf("Parameter kind %d\n",(int)parmKind);*/

  /*short crcc;
    crcc=0;*/

  int appPos;
  /*default position where to append extra info*/
  appPos=(int)sampSize/2;
  /*printf("Default position where to add pitch: %d\n",pitchPos);*/
  if(parmKind&000100) appPos--;/*_E*/
  if(parmKind&020000) appPos--;/*_0*/
  /*printf("New position is %d\n",pitchPos);*/
  parmKind=parmKind&(~010000);
  
  /*check if compressed*/
  if(parmKind&002000){
    /*substract 4 from nSamples (see HParm.c)*/
    nSamples-=4;

    int I;
    float *f,*A,*B,*AA,*BB;
    f=(float *)malloc(sizeof(float)*(sampSize/2));
    A=(float *)malloc(sizeof(float)*(sampSize/2+ncol)); AA=(float *)malloc(sizeof(float)*(ncol));
    B=(float *)malloc(sizeof(float)*(sampSize/2+ncol)); BB=(float *)malloc(sizeof(float)*(ncol));
    if(fread(f,sizeof(float),sampSize/2,file_in1)!=sampSize/2){
      printf("Failed to read compressed A\n");
      exit(1);
    }
    /*printf("A=\n");
    for(i=0;i<sampSize/2;i++){
      printf("%f ",f[i]);
    }
    printf("\n");*/
    for(i=0;i<appPos;i++){
      A[i]=f[i];
    }
    I=i;
    for(i=appPos;i<appPos+ncol;i++){
      A[i]=0.0;
    }
    for(i=appPos+ncol;i<sampSize/2+ncol;i++,I++){
      A[i]=f[I];
    }
    if(fread(f,sizeof(float),sampSize/2,file_in1)!=sampSize/2){
      printf("Failed to read compressed B\n");
      exit(1);
    }
    /*printf("B=\n");
    for(i=0;i<sampSize/2;i++){
      printf("%f ",f[i]);
    }
    printf("\n");*/
    for(i=0;i<appPos;i++){
      B[i]=f[i];
    }
    I=i;
    for(i=appPos;i<appPos+ncol;i++){
      B[i]=0.0;
    }
    for(i=appPos+ncol;i<sampSize/2+ncol;i++,I++){
      B[i]=f[I];
    }
    
    /*find min and max pitch values*/
    int retCode,j;
    float *g,*minf,*maxf;
    if((g=(float *)malloc(sizeof(float)*ncol))==NULL){/*this way can re-use previous entries 
      for back up in case files have different number of samples*/
      printf("Failed to allocate g[]\n"); exit(0);
    }
    if((minf=(float *)malloc(sizeof(float)*ncol))==NULL){
      printf("Failed to allocate minf[]\n"); exit(0);
    }
    if((maxf=(float *)malloc(sizeof(float)*ncol))==NULL){
      printf("Failed to allocate maxf[]\n"); exit(0);
    }
    for(j=0;j<ncol;j++){ minf[j]=FLT_MAX; maxf[j]=FLT_MIN; }
    for(i=0;i<nSamples;i++){
      for(j=0;j<ncol;j++){
        if((retCode=fscanf(file_in2,"%e",&g[j]))!=1){
          if(retCode==EOF){
            printf("Reached end of file. Will repeat %d-th element %e\n",i,g[j]);
          }else{
            printf("Failed to read pitch data for %d-th sample\n",i);
            exit(1);
          }
        }
        if(g[j]<minf[j]) minf[j]=g[j];
        if(g[j]>maxf[j]) maxf[j]=g[j];
      }
    }
    /*for(j=0;j<ncol;j++){
      printf("%d: min %e, max %e\n",j,minf[j],maxf[j]);
    }*/
    for(j=0;j<ncol;j++){
      AA[j]=A[appPos+j]=2.0*32767.0/(maxf[j]-minf[j]);
      SwapFloat(&(A[appPos+j]));
      BB[j]=B[appPos+j]=(maxf[j]+minf[j])*32767.0/(maxf[j]-minf[j]);
      SwapFloat(&(B[appPos+j]));
    }
    /*printf("A=%f, B=%f\n",A[pitchPos],B[pitchPos]);*/
    /*update CRCC*/
    /*crcc=UpdateCRCC(A,sampSize/2+1,sizeof(float),FALSE,crcc);
      crcc=UpdateCRCC(B,sampSize/2+1,sizeof(float),FALSE,crcc);*/

    /*write HTK header*/
    /*convert variables from HTK header back into reversed byte order format*/
    i=nSamples+4; SwapInt(&i);
    if(fwrite(&i,sizeof(int),1,file_out1)!=1){
      printf("Failed to write to %s\n",argv[c]);
      exit(1);
    }
    i=sampPeriod; SwapInt(&i);
    if(fwrite(&i,sizeof(int),1,file_out1)!=1){
      printf("Failed to write to %s\n",argv[c]);
      exit(1);
    }
    s=sampSize+sizeof(short)*ncol; SwapShort(&s);
    if(fwrite(&s,sizeof(short),1,file_out1)!=1){
      printf("Failed to write to %s\n",argv[c]);
      exit(1);
    }
    s=parmKind; SwapShort(&s);
    if(fwrite(&s,sizeof(short),1,file_out1)!=1){
      printf("Failed to write to %s\n",argv[c]);
      exit(1);
    }
    /*write A and B*/
    if(fwrite(A,sizeof(float),sampSize/2+ncol,file_out1)!=(sampSize/2+ncol)){
      printf("Failed to write to %s\n",argv[c]);
      exit(1);
    }
    if(fwrite(B,sizeof(float),sampSize/2+ncol,file_out1)!=(sampSize/2+ncol)){
      printf("Failed to write to %s\n",argv[c]);
      exit(1);
    }
    /*rewind pitch file*/
    rewind(file_in2);
    /*write samples*/
    int J,S;
    short *sa,*SA;
    double d;
    sa=(short *)malloc(sizeof(short)*(sampSize/2));
    SA=(short *)malloc(sizeof(short)*(sampSize/2+ncol));
    for(i=0;i<nSamples;i++){
      if(fread(sa,sizeof(short),sampSize/2,file_in1)!=(sampSize/2)){
        printf("Failed to read %d-th sample\n",i);
        exit(1);
      }/*else{
	printf("Read %d bytes (%d x %d)\n",sizeof(short)*(sampSize/2),sizeof(short),sampSize/2);
      }*/
      /*for(j=0;j<sampSize/2;j++){
	printf("%d ",sa[j]);
      }
      printf("\n");*/
      for(j=0;j<appPos;j++){
        SA[j]=sa[j];
      }
      J=j;
      for(j=appPos+ncol;j<sampSize/2+ncol;j++,J++){
        SA[j]=sa[J];
      }
      
      for(j=0;j<ncol;j++){
        if((retCode=fscanf(file_in2,"%e",&g[j]))!=1){
          if(retCode==EOF){
            printf("Reached end of file %s. Will append the last read pitch value %e\n",argv[1],g[j]);
          }else{
            printf("Failed to read pitch data for %d-th sample\n",i);
            exit(1);
          }
        }
        d = (double)g[j]*(double)AA[j]-(double)BB[j];
        S=(int)((d<0.0)? d-0.5:d+0.5);
        if(S<-32767||S>32767){
          printf("short out of range %d\n",S);
          exit(1);
        }
        SA[appPos+j]=S;
        SwapShort(&(SA[appPos+j]));
      }
      
      if(fwrite(SA,sizeof(short),sampSize/2+ncol,file_out1)!=(sampSize/2+ncol)){
        printf("Failed to write to %s\n",argv[c]);
        exit(1);
      }
      /*compute CRCC*/
      /*crcc=UpdateCRCC(SA,sampSize/2+1,sizeof(float),FALSE,crcc);*/
    }
    /*if(parmKind&010000){
      SwapShort(&crcc);
      if(fwrite(&crcc,sizeof(short),1,file_out1)!=(1)){
	printf("Failed to write to %s\n",argv[3]);
	exit(1);
      }
    }*/
  }else{
    printf("No support for uncompressed files\n");
    exit(0);
  }

  if(fclose(file_in1)!=0){
    printf("Failed to close %s properly\n",argv[1]);
    exit(1);
  }
  if(fclose(file_in2)!=0){
    printf("Failed to close %s properly\n",argv[2]);
    exit(1);
  }
  if(fclose(file_out1)!=0){
    printf("Failed to close %s properly\n",argv[3]);
    exit(1);
  }

  return 0;
}
