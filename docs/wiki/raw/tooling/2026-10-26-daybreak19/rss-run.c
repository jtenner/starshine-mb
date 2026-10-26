#define _GNU_SOURCE
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/resource.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc,char **argv) {
  if (argc<2) return 2;
  long resident=0,pages=0;
  FILE *f=fopen("/proc/self/statm","r");
  if(f) { if(fscanf(f,"%ld %ld",&pages,&resident)!=2) resident=0; fclose(f); }
  pid_t child=fork();
  if(child<0) {perror("fork");return 125;}
  if(child==0) {execvp(argv[1],argv+1);perror("execvp");_exit(127);}
  int status;struct rusage usage;
  while(wait4(child,&status,0,&usage)<0) {if(errno!=EINTR){perror("wait4");return 125;}}
  fprintf(stderr,"DB19_NATIVE_RSS_KIB=%ld\nDB19_SMALL_LAUNCHER_RSS_KIB=%ld\n",usage.ru_maxrss,resident*sysconf(_SC_PAGESIZE)/1024);
  if(WIFEXITED(status)) return WEXITSTATUS(status);
  if(WIFSIGNALED(status)) return 128+WTERMSIG(status);
  return 125;
}
