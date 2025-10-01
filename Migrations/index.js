module.exports = function (migration) {
  const blogPost = migration.editContentType('blogPost');
  blogPost.createField('FieldKeyName').name('SummaryKeyName').type('Text');
};
