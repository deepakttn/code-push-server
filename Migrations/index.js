module.exports = function (migration) {
  const blogPost = migration.editContentType('blogPost');
  blogPost.createField('post').name('Summary').type('Text');
};
