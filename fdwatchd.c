#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>
#include <sys/wait.h>

#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <time.h>
#include <unistd.h>

#include "fdwatchd.h"

struct kevent	*kev;
int		 nkev;

extern int	 yyparse(void);
extern FILE	*yyin;

char	*fflag;
int	 Fflag;

static void
stdfd_to_null(void)
{
	int fd;

	fd = open("/dev/null", O_RDWR);
	if (fd == -1)
		return;
	(void) dup2(fd, STDIN_FILENO);
	(void) dup2(fd, STDOUT_FILENO);
	(void) dup2(fd, STDERR_FILENO);
	setsid();
}

void
fdwatchd_load_config(char *conf)
{
	FILE *fp;

	fp = fopen(conf, "r");
	if (fp == NULL) {
		note(1, "could not load config: %s: %s\n",
		    conf, strerror(errno));
		exit(1);
	}
	yyin = fp;
	yyparse();
	fclose(fp);
}

void
note(int level, char const *const fmt, ...)
{
        va_list ap;
        FILE *fp;

	fp = stdout;
        va_start(ap, fmt);
        (void) fprintf(fp, "fdwatchd: %lu ", time(NULL));
        vfprintf(fp, fmt, ap);
        (void) fflush(fp);
}

int
fdwatchd_handle_event(struct kevent *kep, struct fdwatch *fp)
{
	pid_t pid;
	int status;
	char *op;
	int error;

	if (kep->fflags & NOTE_WRITE)
		op = "write";
	if (kep->fflags & NOTE_DELETE)
		op = "delete";
	if (kep->fflags & NOTE_RENAME)
		op = "rename";
	if (kep->fflags & NOTE_ATTRIB)
		op = "attrib";
	note(1, "%s event on %s identified\n", op, fp->fdw_path);
	pid = fork();
	if (pid == -1) {
		note(1, "failed to launch handler for %s\n",
		    fp->fdw_path);
		return (-1);
	}
	if (pid == 0) {
		(void) execl("/bin/sh", "sh", 
		    fp->fdw_script,
		    fp->fdw_path,
		    op, NULL);
		note(1, "failed to exec script\n");
		_exit(1);
	}
	while (1) {
		error = waitpid(pid, &status, 0);
		if (error == -1 && errno == EINTR)
			continue;
		note(1, "collected exit status %d on pid %d\n", status, pid);
		break;
	}
	return (0);
}

void
fdwatchd_evloop(void)
{
	struct kevent *evlist, *kep;
	struct fdwatch *fwp;
	int error, k;
	int kq;

	evlist = calloc(nkev, sizeof(*evlist));
	if (evlist == NULL) {
		note(1, "failed to allocate kernel event array\n");
		exit(1);
	}
	kq = kqueue();
	if (kq == -1) {
		note(1, "failed to create kernel event queue\n");
		exit(1);
	}
	for (;;) {
		error = kevent(kq, &kev[0], nkev, evlist, nkev, NULL);
		if (error == -1) {
			note(1, "kevent failed: %s\n", strerror(errno));
			exit(1);
		}
		for (k = 0; k < error; k++) {
			kep = &evlist[k];
			fwp = (struct fdwatch *)kep->udata;
			fdwatchd_handle_event(kep, fwp);
		}
	}
}

int
main(int argc, char *argv [])
{
	int ch;
	pid_t pid;

	while ((ch = getopt(argc, argv, "Ff:")) != -1)
		switch (ch) {
		case 'F':
			Fflag = 1;
			break;
		case 'f':
			fflag = optarg;
			break;
		}
	if (Fflag == 0) {
		pid = fork();
		if (pid == -1) {
			note(1, "unable to daemonize: %s\n", strerror(errno));
			exit(1);
		}
		if (pid != 0) {
			(void) fprintf(stdout,
			    "launched into background: pid: %d\n", pid);
			exit(1);
		}
		stdfd_to_null();
	}
	if (fflag == NULL)
		fflag = DEF_CONF_PATH;
	fdwatchd_load_config(fflag);
	fdwatchd_evloop();
	return (0);
}
