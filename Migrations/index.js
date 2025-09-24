module.exports = function (migration) {
  const blogPost = migration.editContentType('blogPost');
  blogPost.createField('Field').name('Summary').type('Text');
};
