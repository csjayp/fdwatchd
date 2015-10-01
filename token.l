%{
#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>

#include "y.tab.h"
#define YY_NO_UNPUT

int lineno = 1;
%}

tokenchar	[^[:blank:];,<>"\n]
tokenstring	{tokenchar}+

%%
\n              lineno++;
[ \t]+          /* ignore whitespace */
\#.*            /* ignore comments */
path		return (PATH);
op		return (OP);
exec		return (EXEC);
write		{
			yylval.mask = NOTE_WRITE;
			return (WRITE);
		}
delete		{
			yylval.mask = NOTE_DELETE;
			return (DELETE);
		}
attrib		{
			yylval.mask = NOTE_ATTRIB;
			return (ATTRIB);
		}
rename		{
			yylval.mask = NOTE_RENAME;
			return (RENAME);
		}
\;		return (SEMICOLON);
\{		return (OBRACE);
\}		return (EBRACE);
\"              {
			char buf[1024], *ptr, c;
			int escaped;

			escaped = 0;
			bzero(buf, sizeof(buf));
			for (ptr = buf; strlen(buf) < (sizeof(buf) - 1);
			    ptr++) {
				c = input();
				if (escaped && c != EOF) {
					*ptr = c;
					escaped = 0;
					continue;
				}
				switch (c) {
				case '\\':
					ptr--;
					escaped = 1;
					break;
				case '\n':
					*ptr = ' ';
					lineno++;
					break;
				case '"':       /* end quote */
					ptr = NULL;
					break;
				case EOF:
					(void) fprintf(stderr, "unmatched \"\n");
					exit(1);
				default:
					*ptr = c;
					break;
				}
				if (ptr == NULL)
					break;
			}
			yylval.str = strdup(buf);
			return (QSTRING);
		}
{tokenstring}	{
			yylval.str = strdup(yytext);
			return (QSTRING);
		}
