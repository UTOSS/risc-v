// Script to post/update PR comment with FPGA metrics comparison
// This script is called from the CI workflow via github-script action

module.exports = async ({github, context}) => {
  const fs = require('fs');
  const comparison = fs.readFileSync('comparison.md', 'utf8');
  
  // Find existing comment
  const { data: comments } = await github.rest.issues.listComments({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: context.issue.number,
  });
  
  const botComment = comments.find(comment => 
    comment.user.type === 'Bot' && 
    comment.body.includes('🔧 DE1-SoC Synthesis Report Summary Diff')
  );
  
  const commentBody = comparison;
  
  if (botComment) {
    // Update existing comment
    await github.rest.issues.updateComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      comment_id: botComment.id,
      body: commentBody
    });
    console.log(`Updated existing comment ${botComment.id}`);
  } else {
    // Create new comment
    await github.rest.issues.createComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      issue_number: context.issue.number,
      body: commentBody
    });
    console.log('Created new comment');
  }
};
