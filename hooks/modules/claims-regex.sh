#!/usr/bin/env bash
# One material-claim vocabulary, on decoded assistant prose (never raw JSON).
# Both Stop paths and provider bridges call evidence-gate.sh, which sources this.
# Lexical coverage is a floor; this does not recognize every possible paraphrase.
export CLAIMS_CLAIM_RE='(?P<deploy>\b(deployed|shipped|released|live|gone[ -]live|go-?live|in production|production[- ]ready|rolled[ -]out|cut over|pushed to (prod|production|vps))\b)|\b(done|passed|failed|complete[d]?|implemented|verified|confirmed|working|works?|fixed|clean|built|added|restored|refreshed|exists?|contains?|supports?|cannot|impossible|unavailable|registered|carries|carry|tells? apart)\b|\b(all )?(checks|tests) pass|pixel[- ]perfect|matches the design|not found|does not|do not support|no (MCP |hook |provider )?(registration|support|hooks?|files?|results?|matches)|now (carry|tells?|has|have)|tells? .{0,60} apart'
# Hedges do not exempt a turn. Deployment proof retains the existing served-artifact
# signals, now accepted only from the matching completed tool result.
export CLAIMS_HEDGE_RE='not verified|unverified|not visually verified|UNRUN|could not verify|I have not|did not check|unchecked'
export CLAIMS_EVIDENCE_RE='SUCCESS\s*[·:|]\s*\w+\s*=\s*\S+|served commit == intended.*running container'
