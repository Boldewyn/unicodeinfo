
SHELL := /bin/bash
UNICODE_VERSION = 9.0.0
DB = db/ucd.sqlite
UNIFONT = 1
WIKIPEDIA = 1

.PHONY: clean dist-clean sql db all

all: db

db: $(DB)

sql: db/unicodeinfo.sql

db/unicodeinfo.sql: data/ucd.all.flat.xml db/blocks.sql db/alias.sql db/propval.sql db/db.py db/images.sql db/wp.sql db/namedsequences.sql db/confusables.sql
	$(info * Compile global SQL file)
	@cat db/create.sql > db/unicodeinfo.sql
	@(cd db; python db.py; cat unicodeinfo.tmp.sql >> unicodeinfo.sql)
	@rm -f db/unicodeinfo.tmp.sql
	@cat db/alias.sql >> db/unicodeinfo.sql
	@cat db/blocks.sql >> db/unicodeinfo.sql
	@cat db/propval.sql >> db/unicodeinfo.sql
	@cat db/images.sql >> db/unicodeinfo.sql
	@cat db/wp.sql >> db/unicodeinfo.sql
	@cat db/namedsequences.sql >> db/unicodeinfo.sql
	@cat db/confusables.sql >> db/unicodeinfo.sql

$(DB): db/unicodeinfo.sql
	$(info * Create SQLite database)
	@true > "$(DB)"
	@python db/insert.py db/unicodeinfo.sql "$(DB)"

data/ucd.all.flat.xml:
	$(info * Fetch Unicode $(UNICODE_VERSION) XML data)
	@mkdir -p data
	@wget -q -O data/ucd.all.flat.zip http://www.unicode.org/Public/$(UNICODE_VERSION)/ucdxml/ucd.all.flat.zip
	@cd data; unzip -qq ucd.all.flat.zip
	@rm -f data/ucd.all.flat.zip

data/unicode/Blocks.txt: data/unicode/ReadMe.txt
data/unicode/Scripts.txt: data/unicode/ReadMe.txt
data/unicode/PropertyValueAliases.txt: data/unicode/ReadMe.txt

data/unicode/ReadMe.txt:
	$(info * Fetch Unicode Standard data)
	@mkdir -p data/unicode
	@wget -q -O data/unicode/UCD.zip http://www.unicode.org/Public/zipped/$(UNICODE_VERSION)/UCD.zip
	@cd data/unicode; unzip -qq -o UCD.zip
	@rm -f data/unicode/UCD.zip

data/htmlentities.json:
	@wget -q -O $@ https://html.spec.whatwg.org/entities.json

dist-clean: clean
	-rm -f -r data
	-rm -f "$(DB)"

clean:
	-rm -f db/unicodeinfo*.sql
	-rm -f db/blocks.sql
	-rm -f db/htmlentities.sql
	-rm -f db/alias.sql
	-rm -f db/propval.sql
	-rm -f db/digraphs.sql
	-rm -f db/namedsequences.sql
	-rm -f db/images.sql
	-rm -f db/wp.sql*
	-rm -f db/confusables.sql

db/blocks.sql: data/unicode/Blocks.txt db/blocks.py
	cd db; python blocks.py

db/digraphs.sql: data/rfc1345.txt
	$(info * Fetch and process digraphs from RFC 1345)
	@cat data/rfc1345.txt | \
	 sed -n '/^ [^ ]\{1,6\} \+[0-9A-Fa-f]\{4\}    [^ ].*$$/p' | \
	 sed 's/^ \([^ ]\{1,6\}\) \+\([0-9A-Fa-f]\{4\}\)    [^ ].*$$/\1\t\2/' > db/digraphs.tmp
	@perl -p -e 's/^([^\t]+)\t([0-9a-f]{4})$$/"INSERT INTO codepoint_alias (cp, alias, `type`) VALUES (".hex("$$2").", '"'"'".join("'"''"'", split("'"'"'", $$1))."'"'"', '"'digraph'"');"/e' db/digraphs.tmp > db/digraphs.sql
	@rm db/digraphs.tmp

data/rfc1345.txt:
	$(info * Fetch RFC 1345)
	@mkdir -p data
	@wget -q -O "$@" http://www.rfc-editor.org/rfc/rfc1345.txt

db/htmlentities.sql: data/htmlentities.json
	cd db; python htmlentities.py
	sort -n $@ -o $@

db/alias.sql: db/htmlentities.sql db/digraphs.sql db/alias.py
	$(info * Collect aliases for codepoints)
	@true > $@
	@cat db/htmlentities.sql db/digraphs.sql > $@
	@cd db; python alias.py

db/propval.sql: db/propval.py
	cd db; python propval.py

db/namedsequences.sql: db/namedsequences.py
	cd db; python namedsequences.py

db/images.sql: data/unifont/uni0000.png
	if [[ "$(UNIFONT)" == "1" ]]; then db/unifont.sh; else touch "$@"; fi

db/wp.sql: db/wp.py
	if [[ "$(WIKIPEDIA)" == "1" ]]; then cd db; python wp.py; else touch "$@"; fi

db/confusables.sql: db/confusables.py data/confusables.txt
	cd db; python confusables.py

data/confusables.txt:
	$(info * Fetch confusables from Unicode)
	@mkdir -p data
	@wget -q -O "$@" http://www.unicode.org/Public/security/latest/confusables.txt

data/unifont/uni0000.png:
	$(info * Fetch UniFont data)
	@mkdir -p data/unifont
	@for x in $$(seq 0 15); do for y in $$(seq 0 15); do \
		wget -q -O $$(printf 'data/unifont/uni00%X%X.png' $$x $$y) \
		$$(printf 'http://unifoundry.com/png/plane00/uni00%X%X.png' $$x $$y); \
		done; done
	@for x in $$(seq 0 15); do for y in $$(seq 0 15); do \
		wget -q -O $$(printf 'data/unifont/uni01%X%X.png' $$x $$y) \
		$$(printf 'http://unifoundry.com/png/plane01/uni01%X%X.png' $$x $$y); \
		done; done
	@wget -q -O data/unifont/uni0E00.png http://unifoundry.com/png/plane0E/uni0E00.png
	@wget -q -O data/unifont/uni0E01.png http://unifoundry.com/png/plane0E/uni0E01.png

