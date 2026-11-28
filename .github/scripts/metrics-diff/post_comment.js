// Script to post/update PR comment with synthesis & hardening metrics comparison.
// Called from the CI workflow via actions/github-script.
//
// Full raw text reports live in the uploaded `comparison.md` CI artifact and the
// CI Job Summary; the PR comment strips the inline `<details>` raw report blocks
// and links directly to both so the comment stays concise and within GitHub's
// 65,536-character limit.

const MAX_COMMENT_LENGTH = 65000;

function formatPrComment(markdown, { artifactUrl = null, summaryUrl = null } = {}) {
  const blockRegex = /\n?<!-- FULL_REPORT_START -->[\s\S]*?<!-- FULL_REPORT_END -->\n?/g;
  let body = markdown.replace(blockRegex, '\n').replace(/\n{3,}/g, '\n\n').trimEnd();

  const links = [];
  if (artifactUrl) {
    links.push(`[Download full report (\`comparison.md\`)](${artifactUrl})`);
  }
  if (summaryUrl) {
    links.push(`[View full report in CI Job Summary](${summaryUrl})`);
  }

  const linksFooter = links.length > 0
    ? `\n\n> **Full text reports:** ${links.join(' · ')}\n`
    : '\n';

  if (body.length + linksFooter.length > MAX_COMMENT_LENGTH) {
    const truncNote = '\n\n_Diff tables truncated to fit GitHub\'s 65KB comment limit._';
    const budget = MAX_COMMENT_LENGTH - truncNote.length - linksFooter.length;
    body = body.slice(0, Math.max(0, budget)).trimEnd() + truncNote;
  }

  return body + linksFooter;
}

module.exports = async ({ github, context, comparisonFile, artifactUrl = null }) => {
  const fs = require('fs');
  const reportPath = comparisonFile;

  if (!reportPath) {
    throw new Error('comparisonFile parameter is required');
  }

  const comparison = fs.readFileSync(reportPath, 'utf8');
  const summaryUrl = (context.serverUrl && context.runId)
    ? `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`
    : null;
  const commentBody = formatPrComment(comparison, {
    artifactUrl: artifactUrl || null,
    summaryUrl,
  });

  // Find existing comment
  const { data: comments } = await github.rest.issues.listComments({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: context.issue.number,
  });
  const botComment = comments.find(comment =>
    comment.user.type === 'Bot' &&
    (comment.body.includes('Synthesis, Hardening & Benchmark Report Summary Diff') ||
     comment.body.includes('Synthesis & Hardening Report Summary Diff') ||
     comment.body.includes('🔧 DE1-SoC Synthesis Report Summary Diff'))
  );

  if (botComment) {
    await github.rest.issues.updateComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      comment_id: botComment.id,
      body: commentBody,
    });
    console.log(`Updated existing comment ${botComment.id}`);
  } else {
    await github.rest.issues.createComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      issue_number: context.issue.number,
      body: commentBody,
    });
    console.log('Created new comment');
  }
};

module.exports.formatPrComment = formatPrComment;
