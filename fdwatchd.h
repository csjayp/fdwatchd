#ifndef FDWATCHD_DOT_H_
#define	FDWATCHD_DOT_H_

#define	DEF_CONF_PATH	"/usr/local/etc/fdwatchd.conf"

void	note(int, char const *const fmt, ...);

struct fdwatch {
	char	fdw_path[1024];
	char	fdw_script[1024];
};

#endif	/*  FDWATCHD_DOT_H_ */
