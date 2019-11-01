all: update pdf

# Update option-list from `d8 --help` output
update: v8.1
v8.1:
	./update.pl v8.1
	git diff

# Generate shiny PDF document
pdf:
	groff -Tpdf -man v8.1 -Z \
	| perl -0pE 's/^x init\R\Kp1\R.*?\R(p1$$)/$$1/ms' \
	| gropdf > v8.1.pdf
