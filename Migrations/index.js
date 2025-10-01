module.exports = function (migration) {
  const blogPost = migration.editContentType('blogPost');

  blogPost.createField('summaryKeyName')
    .name('Summary')
    .type('Text');

  blogPost.createField('author')
    .name('Author')
    .type('Symbol');

  blogPost.createField('publishDate')
    .name('Publish Date')
    .type('Date');

  blogPost.createField('tags')
    .name('Tags')
    .type('Array')
    .items({ type: 'Symbol' });

  blogPost.createField('featuredImage')
    .name('Featured Image')
    .type('Link')
    .linkType('Asset');
};
