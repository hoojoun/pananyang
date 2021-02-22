#!/usr/bin/env perl

use v5.16;
use utf8;

use Mojolicious::Lite;

use DBI;
#DB 설정
my $DBH = DBI->connect(
    'dbi:mysql:Book',
	#DB오류시 확인
	#'root',
	#'*Hay990729', #password(mysql)
	'user',
	'0000',
    {
        RaiseError        => 1,
        AutoCommit        => 1,
        mysql_enable_utf8 => 1,
    },
);

# 비슷한 구문 처리
helper db_select => sub {
    my ( $self, $input_id ) = @_;

    my $sth = $DBH->prepare(qq{ SELECT * FROM MEMO WHERE id=$input_id});
    $sth->execute();

    my %articles;
    my ( $db_id, $name, $title, $content, $date ) = $sth->fetchrow_array;
    my ($wdate) = split / /, $date;

    $articles{$db_id} = {
        name    => $name,
        title   => $title,
        content => $content,
        wdate   => $wdate,
    };
    return \%articles;
};

# 기본 시작 페이지는 /login
get '/' => sub {
    my $self = shift;

    $self->redirect_to( $self->url_for('/login') );
};

# 리스트 보여주기
get '/:userid/list' => sub {
    my $self = shift;

	my $userid=$self->param('userid'); #사용자 id 문자열 가져오기
    my $sth = $DBH->prepare(qq{ SELECT id, name, title, content, wdate FROM MEMO });
    $sth->execute();
	
	# 게시글 가져오기 
    my %articles;
    while ( my @row = $sth->fetchrow_array ) {
        my ( $id, $name, $title, $content, $date ) = @row;
        my ($wdate) = split / /, $date;
        $articles{$id} = {
            name    => $name,
            title   => $title,
            content => $content,
            wdate   => $wdate,
        };
    }
    $self->session(USERID=>$userid);	
    $self->stash( articles => \%articles );
	$self->render('list');
};

#회원가입
get '/createID' => sub { 
  my $self = shift;

  $self->render('createID');
};

#회원가입 할 id, passwd 저장 (!!중복 검사 미구현[참고 /protected])
post '/createID' => sub { #디비로 저장하는 POST
    my $self = shift;
 
    my $userid   = $self->param('userid');
    my $passwd   = $self->param('passwd');
 
    my $sth = $DBH->prepare(qq{
        INSERT INTO `USER` (`userid`,`passwd`) VALUES (?,?)
    });
    $sth->execute($userid, $passwd);
    #$self->redirect_to( $self->url_for('/login') ); #조건에 따라 경로가 달라져야함 추후 수정
};

# 로그인 화면
get '/login' => sub {
  my $self = shift;

  $self->render('login');
};

# id, passwd가 유효한지 검사하는 페이지
get '/protected'=>sub{
	my $self=shift;
	$self->render('protected');
};

post '/protected'=> sub{
	my $self=shift;

	my $ID=$self->param('loginId');
	my $PASSWD=$self->param('password');
	
	# DB에서 데이터를 가져와 유효한지 확인
	my $sth=$DBH->prepare(qq{SELECT userid,passwd FROM USER});
	$sth->execute();
	my $select=0;
    my %articles;
	while(my @row=$sth->fetchrow_array){
		my($userid, $passwd)=@row;
		if(($ID eq $userid)&&($PASSWD eq $passwd)){
			$select=1;
		}
	}
	if($select==1){
		$self->redirect_to($self->url_for($ID.'/list'));
	}
	else{
		$self->redirect_to($self->url_for('/login'));
	}
};

# 로그인
##################################################
# 게시판

# 게시글 쓰기
get '/:userid/write' => sub {
  my $self = shift;
 
  $self->render('write');
};

post '/:userid/write' => sub {
    my $self = shift;
	
    my $name    = $self->param('userid');#name form 정리 필요
    my $title   = $self->param('title');
    my $content = $self->param('content');

    my $sth = $DBH->prepare(qq{
        INSERT INTO `MEMO` (`name`,`title`,`content`) VALUES (?,?,?)
    });
    $sth->execute( $name, $title, $content );

    $self->redirect_to( $self->url_for('list') );
};

# 게시글 읽기
get '/:userid/read/:id' => sub {
    my $self = shift;
    my $input_id = $self->param('id');

    my $articles = $self->db_select ( $input_id );
    my ($id)     = keys %$articles;

    $self->stash(
        articles => $articles,
        id       => $id,
    );
    $self->render('read');
};

# 게시글 편집
get '/:userid/edit/:id' => sub {
    my $self = shift;

    my $input_id = $self->param('id');

    my $articles = $self->db_select ( $input_id );
    my ($id)     = keys %$articles;

    $self->stash(
        articles => $articles,
        id       => $id,
    );
    $self->render('edit');
};

post '/:userid/edit' => sub {
    my $self = shift;

	my $userid  = $self->param('userid');
    my $id      = $self->param('id');
    warn $id;
    my $name    = $self->param('name');
    my $title   = $self->param('title');
    my $content = $self->param('content');

    my $sth = $DBH->prepare(qq{
        UPDATE `MEMO` SET `name`=?,`title`=?,`content`=? WHERE `id`=$id
    });
    $sth->execute( $name, $title, $content );

    $self->redirect_to( $self->url_for('/'.$userid.'/list') );
};
 
#게시글 삭제
get '/:userid/delete/:id' => sub {
    my $self = shift;

	my $userid= $self->param('userid');
    my $id = $self->param('id');

    my $sth = $DBH->prepare(qq{ DELETE FROM `MEMO` WHERE `id`=$id });
    $sth->execute();

    $self->redirect_to( $self->url_for('/'.$userid.'/list') );
};

app->start;

##############################################
__DATA__
@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
  </head>
  <body>
    <%= content %>
  </body>
</html>


##########로그인##############
@@ login.html.ep
% layout 'default';
% title 'SIGN IN';
<style>
a {
    color: #333;
    text-decoration: none;
    float: right;
}
input {
    -webkit-writing-mode: horizontal-tb !important;
    text-rendering: auto;
    color: initial;
    letter-spacing: normal;
    word-spacing: normal;
    text-transform: none;
    text-indent: 0px;
    text-shadow: none;
    display: inline-block;
    text-align: start;
    -webkit-appearance: textfield;
    background-color: white;
    -webkit-rtl-ordering: logical;
    cursor: text;
    margin: 0em;
    font: 400 13.3333px Arial;
    padding: 1px 0px;
    border-width: 2px;
    border-style: inset;
    border-color: initial;
    border-image: initial;
}
.inner_login {
    position: absolute;
    left: 50%;
    top: 50%;
    margin: -145px 0 0 -160px;
}
.login_pananyang{
        position: relative;
        width: 320px;
        margin: 0 auto;
    }
.screen_out {
    position: absolute;
    width: 0;
    height: 0;
    overflow: hidden;
    line-height: 0;
    text-indent: -9999px;    
}
body, button, input, select, td, textarea, th {
    font-size: 13px;
    line-height: 1.5;
    -webkit-font-smoothing: antialiased;
}    
fieldset, img {
    border: 0;
}
.login_pananyang .box_login {
    margin: 35px 0 0;
    border: 1px solid #ddd;
    border-radius: 3px;
    background-color: #fff;
    box-sizing: border-box;
}
.login_pananyang .inp_text {
    position: relative;
    width: 100%;
    margin: 0;
    padding: 18px 19px 19px;
    box-sizing: border-box;
}
.login_pananyang .inp_text+.inp_text {
    border-top: 1px solid #ddd;
}
.inp_text input {
    display: block;
    width: 100%;
    height: 100%;
    font-size: 13px;
    color: #000;
    border: none;
    outline: 0;
    -webkit-appearance: none;
    background-color: transparent;
}
.btn_login {
    margin: 20px 0 0;
    width: 100%;
    height: 48px;
    border-radius: 3px;
    border-color: #777;
    font-size: 16px;
    color: #fff;
    background-color: #777;
}
</style>

<div class="inner_login">
    <div class="login_pananyang">

        <form action="/protected" method="post">
            <fieldset>
            <legend class="screen_out">로그인 정보 입력폼</legend>
            <div class="box_login">
                <div class="inp_text">
                <label for="loginId" class="screen_out">아이디</label>
                <input type="text" id="loginId" name="loginId" placeholder="ID" >
                </div>
                <div class="inp_text">
                <label for="loginPw" class="screen_out">비밀번호</label>
                <input type="password" id="loginPw" name="password" placeholder="Password" >
                </div>
            </div>
            <button type="submit" class="btn_login"  anabled>로그인</button> 
                <span class="txt_find">
                <a href="http://127.0.0.1:3000/createID" class="link_find">아직 회원이 아니시라면 / 회원가입 </a>
                </span>
            </div>
            </fieldset>
        </form>
        
    </div>
</div>

@@protected.html.ep
%layout 'default';
%title 'PROTECTED';

############로그인 HTML################
###########회원가입 HTML###############
@@ createID.html.ep
% layout 'default';
% title 'SIGN UP';
<style>
a {
    color: #333;
    text-decoration: none;
    float: right;
}
input {
    -webkit-writing-mode: horizontal-tb !important;
    text-rendering: auto;
    color: initial;
    letter-spacing: normal;
    word-spacing: normal;
    text-transform: none;
    text-indent: 0px;
    text-shadow: none;
    display: inline-block;
    text-align: start;
    -webkit-appearance: textfield;
    background-color: white;
    -webkit-rtl-ordering: logical;
    cursor: text;
    margin: 0em;
    font: 400 13.3333px Arial;
    padding: 1px 0px;
    border-width: 2px;
    border-style: inset;
    border-color: initial;
    border-image: initial;
}
.inner_createID {
    position: absolute;
    left: 50%;
    top: 50%;
    margin: -145px 0 0 -160px;
}
.createID_pananyang{
        position: relative;
        width: 320px;
        margin: 0 auto;
    }
.screen_out {
    position: absolute;
    width: 0;
    height: 0;
    overflow: hidden;
    line-height: 0;
    text-indent: -9999px;    
}
body, button, input, select, td, textarea, th {
    font-size: 13px;
    line-height: 1.5;
    -webkit-font-smoothing: antialiased;
}    
fieldset, img {
    border: 0;
}
.createID_pananyang .box_createID {
    margin: 35px 0 0;
    border: 1px solid #ddd;
    border-radius: 3px;
    background-color: #fff;
    box-sizing: border-box;
}
.createID_pananyang .inp_text {
    position: relative;
    width: 100%;
    margin: 0;
    padding: 18px 19px 19px;
    box-sizing: border-box;
}
.createID_pananyang .inp_text+.inp_text {
    border-top: 1px solid #ddd;
}
.inp_text input {
    display: block;
    width: 100%;
    height: 100%;
    font-size: 13px;
    color: #000;
    border: none;
    outline: 0;
    -webkit-appearance: none;
    background-color: transparent;
}
.btn_createID {
    margin: 20px 0 0;
    width: 100%;
    height: 48px;
    border-radius: 3px;
    border-color: #777;
    font-size: 16px;
    color: #fff;
    background-color: #777;
}
</style>




<div class="inner_createID">
    <div class="createID_pananyang">

        <form action="/createID" method="post">
            <fieldset>
            <legend class="screen_out">회원가입 정보 입력폼</legend>
            <div class="box_createID">
                <div class="inp_text">
                <label for="loginId" class="screen_out">아이디</label>
                <input type="text" id="userid" name="userid" placeholder="20자 이내의 문자열을 입력하세요" >
                </div>
                <div class="inp_text">
                <label for="loginPw" class="screen_out">비밀번호</label>
                <input type="password" id="passwd" name="passwd" placeholder="10자 이내의 숫자를 입력하세요" >
                </div>
            </div>
            <button type="submit" class="btn_createID"  anabled>가입하기</button> 
            </fieldset>
        </form>
    </div>
</div>

###########회원가입 HTML###############

########## 게시글 쓰기 ###############

@@ write.html.ep
% layout 'default';
% title 'WRITE';
      <form action="/<%= session 'USERID' %>/write" method="post">
        <table width=580 border=0 cellpadding=2 cellspacing=1 bgcolor=#777777>
          <tr>
            <td height=20 colspan=4 align=center bgcolor=#999999>
              <font color=white><b>글쓰기</b></font>
            </td>
          </tr>
          <tr>
            <td bgcolor=white>
              <table bgcolor=white>
                <tr>
                  <td>이름</td>
                  <td><input type="text" name="name"></td>
                </tr>
                <tr>
                  <td>제목</td>
                  <td><input type="text" name="title"></td>
                </tr>
                <tr>
                  <td>내용</td>
                  <td colspan=4>
                    <textarea name="content" cols=80 rows=5></textarea>
                  </td>
                </tr>
                <tr>
                  <td colspan=10 align=center>
                    <input type="submit" value="저장">
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        <tr>
          <td bgcolor=#999999>
            <table width=100%>
              <tr>
                <td>
                  <a href='/<%= session 'USERID' %>/list' style="text-decoration:none;"><font color=white>[목록보기]</font></a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
        </table>
      </form>

###############################

######## 리스트############### 

@@ list.html.ep
% layout 'default';
% title 'LIST';
        <table width=580 border=0 cellpadding=2 cellspacing=1 bgcolor=#999999>
        <tr height=20 colspan=4 align=center bgcolor=#CCCCCC >
          <td color=white>No. </td>
          <td>제목</td>
          <td>글쓴이</td>
          <td>date</td>
        </tr>
        % for my $id ( reverse sort { $a <=> $b } keys %$articles ) {
        <tr bgcolor="white">
          <td><%= $id %></td>
          <td><a href="/<%=session 'USERID' %>/read/<%= $id %>"><%= $articles->{$id}{title} %></a></td>
          <td><%= $articles->{$id}{name} %></td>
          <td><%= $articles->{$id}{wdate} %></td>
        </tr>
        % }
        <tr>
          <td colspan=4 bgcolor=#999999>
            <table width=100%>
              <tr>
                <td width=2000 align=center height=20>
				<a href="/<%= session 'USERID' %>/write" style="text-decoration:none;"><font color=white>[글쓰기]</font></a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>

#################################

######### 게시글 읽기 ##########

@@ read.html.ep
% layout 'default';
% title 'READ';
      <table width=580 border=0 cellpadding=2 cellspacing=1 bgcolor=#777777>
        <tr>
          <td height=20 colspan=4 align=center bgcolor=#999999>
            <font color=white><b><%= $articles->{$id}{title} %></b></font>
          </td>
        </tr>
        <tr>
          <td width=50 height=20 align=center bgcolor=#EEEEEE> 글쓴이 </td>
          <td width=240 bgcolor=white> <%= $articles->{$id}{name} %> </td>
          <td width=50 height=20 align=center bgcolor=#EEEEEE> 날짜 </td>
          <td width=240 bgcolor=white> <%= $articles->{$id}{wdate} %> </td>
        </tr>
        <tr>
          <td bgcolor=white colspan=4>
            <font color=black>
              <pre><%= $articles->{$id}{content} %></pre>
            </font>
          </td>
        </tr>
        <tr>
          <td colspan=4 bgcolor=#999999>
            <table width=100%>
              <tr>
                <td width=2000 align=left height=20>
                  <a href='/<%=session 'USERID' %>/list' style="text-decoration:none;"><font color=white>[목록보기]</font></a>
                  <a href='/<%=session 'USERID' %>/write' style="text-decoration:none;"><font color=white>[글쓰기]</font></a>
                  <a href='/<%=session 'USERID' %>/edit/<%= $id %>' style="text-decoration:none;"><font color=white>[수정]</font></a>
                  <a href='/<%=session 'USERID' %>/delete/<%= $id %>' style="text-decoration:none;"><font color=white>[삭제]</font></a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>

##################################

############편집 하기############

@@ edit.html.ep
% layout 'default';
% title 'EDIT';
      <form action="/<%=session 'USERID' %>/edit" method="post">
        <input type="hidden" name="id" value="<%= $id %>">
        <table width=580 border=0 cellpadding=2 cellspacing=1 bgcolor=#777777>
          <tr>
            <td height=20 colspan=4 align=center bgcolor=#999999>
              <font color=white><b>수정</b></font>
            </td>
          </tr>
          <tr>
            <td bgcolor=white>
              <table bgcolor=white>
                <tr>
                  <td>이름</td>
                  <td><input type="text" name="name" value="<%= $articles->{$id}{name} %>"></td>
                </tr>
                <tr>
                  <td>제목</td>
                  <td><input type="text" name="title" value="<%= $articles->{$id}{title} %>"></td>
                </tr>
                <tr>
                  <td>내용</td>
                  <td colspan=4>
                    <textarea name="content" cols=80 rows=5><%= $articles->{$id}{content} %></textarea>
                  </td>
                </tr>
                <tr>
                  <td colspan=10 align=center>
                    <input type="submit" value="수정확인">
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        <tr>
          <td bgcolor=#999999>
            <table width=100%>
              <tr>
                <td>
                  <a href='/<%=session 'USERID' %>/list' style="text-decoration:none;"><font color=white>[목록보기]</font></a>
                  <a href='/<%=session 'USERID' %>/write' style="text-decoration:none;"><font color=white>[글쓰기]</font></a>
                  <a href='/<%=session 'USERID' %>/read/<%= $id %>' style="text-decoration:none;"><font color=white>[취소]</font></a>
                  <a href='/<%=session 'USERID' %>/delete/<%= $id %>' style="text-decoration:none;"><font color=white>[삭제]</font></a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
        </table>
      </form>
