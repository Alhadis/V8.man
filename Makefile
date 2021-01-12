all: update pdf

# Update option-list from `d8 --help` output
update:
	./update.pl v8.1
	git diff

.PHONY: update

# Generate shiny PDF document
pdf: v8.1.pdf
v8.1.pdf: v8.1
	groff -Tpdf -man $^ -Z \
	| perl -0pE 's/^x init\R\Kp1\R.*?\R(p1$$)/$$1/ms' \
	| gropdf > $@
