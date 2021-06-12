<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:npo="http://xmlns.sven.to/npo">
	<npo:comment>
		Extract a comma-separated list of all reachable ports - open, closed.
	</npo:comment>
	<npo:category>extract</npo:category>

	<xsl:output method="text" />
	<xsl:strip-space elements="*" />

	<xsl:key name="portid" match="/nmaprun/host/ports/port/state[@state = 'open' or @state = 'closed' or @state = 'unfiltered']/../@portid" use="." />

	<xsl:template match="/">
		<xsl:for-each select="/nmaprun/host/ports/port/state[@state = 'open' or @state = 'closed' or @state = 'unfiltered']/../@portid[generate-id() = generate-id(key('portid',.)[1])]">
			<xsl:if test="position() != 1">
				<xsl:text>,</xsl:text>
			</xsl:if>
			<xsl:value-of select="."/>
		</xsl:for-each>
	</xsl:template>

	<xsl:template match="text()" />
</xsl:stylesheet>