SHELL := /bin/bash

test:
	prove -I./lib -I./t/lib -r t

cover:
	cover -delete
	HARNESS_PERL_SWITCHES=-MDevel::Cover prove -I./lib -I./t/lib -r t
	cover -report html_basic
