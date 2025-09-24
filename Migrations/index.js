module.exports = function (migration) {
  const blogPost = migration.editContentType('blogPost');
  blogPost.createField('FieldKey').name('SummaryKey').type('Text');
};
