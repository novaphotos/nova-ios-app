PRODUCT_NAME="NovaCamera"
COMPANY_NAME="Sneaky Squid"
PRODUCT_ID="com.sneakysquid.novacamera"
SRC_DIR="NovaCamera"
DOC_DIR="docs"

docs:
	appledoc \
		-o ${DOC_DIR} \
		-p ${PRODUCT_NAME} \
		-c ${COMPANY_NAME} \
		--company-id ${PRODUCT_ID} \
		--keep-intermediate-files \
		--keep-undocumented-objects \
		--keep-undocumented-members \
		${SRC_DIR} \
		|| true
