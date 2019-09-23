all: update pdf

# Update option-list from `d8 --help` output
update: v8.1
v8.1:
	./update.pl v8.1
	git diff

# Generate shiny PDF document
pdf:
	groff -Tpdf -man v8.1 > v8.1.pdf
