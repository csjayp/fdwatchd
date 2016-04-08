/*-
 * Copyright (c) 2016 Christian S.J. Peron
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
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
