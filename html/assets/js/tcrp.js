
$(document).ready(function () {
  console.log("document loaded");
 
  $('#myform').val("$MODEL");
  $('#mymodel').change( function() {
     $('#myform').submit();
       $.ajax({ // create an AJAX call...
           data: $(this).serialize(), // get the form data
           type: $(this).attr('method'), // GET or POST
           url: $(this).attr('action'), // the file to call
           success: function(response) { // on success..
               $('#output').html(response); // update the DIV
         }
        });
        console.log("form myform changed");
       return false; // cancel original event to prevent form submitting
   });
  
  $('#myversion').val("$VERSION");
  $('#myversion').change( function() {
     $('#myversion').submit();
       $.ajax({ // create an AJAX call...
           data: $(this).serialize(), // get the form data
           type: $(this).attr('method'), // GET or POST
           url: $(this).attr('action'), // the file to call
           success: function(response) { // on success..
               $('#output').html(response); // update the DIV
           }
       });
             console.log("form myversion changed");
       return false; // cancel original event to prevent form submitting
   });
  
  $('#addextbutton').click(function(){

         $.ajax({
          data: $(this).serialize(), // get the form data
           data:  { "exturl" : $('#extensionlist').val(), "action" : "extadd"},
           type: 'POST',
           //   type: $(this).attr('post'), // GET or POST
           //url: "/actions.sh?action=extadd&ext=" + $('#extensionlist').val() + "&url=$exturl&platform=$MODEL", // the file to call
           url: "/actions.sh?action=extadd&ext=" + $('#extensionlist').val() + "&url=$exturl&platform=$MODEL", // the file to call
             success: function(data) {
             console.log(`Button addextbutton pressed loading : ${location.href}#extmanagement  ` + $('#extensionlist').val()) ;
                 //alert(data);
               $("extensionmanagement").text(data);
               location.reload();
             }
         });
       // $('#extmanagement').load(location.href );
  });
  $('#remextbutton').click(function(){

         $.ajax({
          data: $(this).serialize(), // get the form data
           data:  { "exturl" : $('#extensionpayloadlist').val(), "action" : "extrem"},
           type: 'POST',
           //   type: $(this).attr('post'), // GET or POST
           //url: "/actions.sh?action=extadd&ext=" + $('#extensionlist').val() + "&url=$exturl&platform=$MODEL", // the file to call
           url: "/actions.sh?action=extrem&ext=" + $('#extensionlist').val() + "&url=$exturl&platform=$MODEL", // the file to call
             success: function(data) {
             console.log(`Button remextbutton pressed removing : ${location.href}#extmanagement  ` + $('#extensionlist').val()) ;
                 //alert(data);
               $("extensionmanagement").text(data);
               location.reload();
             }
         });
       // $('#extmanagement').load(location.href );
      });
  
});


function onModelChange() {
  var x = document.getElementById("myModel").value;
  document.getElementById("model").innerHTML = "You selected: " + x;
}

