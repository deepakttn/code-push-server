module.exports = function (migration) {
  const blogPost = migration.editContentType('blogPost');
  blogPost.createField('summary').name('Summary').type('Text');
};
