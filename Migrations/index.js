module.exports = function (migration, context) {
  const blogPost = migration.editContentType('blogPost');

  blogPost.editField('summaryKeyName')
    .name('Summary')
    .type('Text');

  blogPost.editField('author')
    .name('Author')
    .type('Symbol');

  blogPost.editField('publishDate')
    .name('Publish Date')
    .type('Date');

  blogPost.editField('tags')
    .name('Tags')
    .type('Array')
    .items({ type: 'Symbol' });
};
