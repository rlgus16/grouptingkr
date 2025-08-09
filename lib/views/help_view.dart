import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';

class HelpView extends StatelessWidget {
  const HelpView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('도움말'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 자주 묻는 질문 섹션인데 나중에 여기 부분 수정해 주시거나 notion로 정리한 다음 웹뷰로 연동해서 봐주시면 좋습니다!
            _buildSectionCard(
              title: '자주 묻는 질문',
              icon: Icons.help_outline,
              child: Column(
                children: [
                  _buildFAQItem(
                    question: '그룹팅은 어떻게 시작하나요?',
                    answer: '1. 프로필을 완성하세요\n'
                        '2. 친구들을 초대하거나 혼자 매칭을 시작하세요\n'
                        '3. 매칭이 완료되면 채팅을 통해 대화를 나누세요\n'
                        '4. 실제 만남을 계획해보세요',
                  ),
                  _buildFAQItem(
                    question: '1:1 매칭과 그룹 매칭의 차이는 무엇인가요?',
                    answer: '1:1 매칭: 혼자서 다른 1명과 매칭되는 방식입니다.\n'
                        '그룹 매칭: 2-5명의 친구들과 함께 같은 인원 수의 다른 그룹과 매칭되는 방식입니다.',
                  ),
                  _buildFAQItem(
                    question: '매칭은 어떤 기준으로 이루어지나요?',
                    answer: '매칭은 다음 기준으로 이루어집니다:\n'
                        '- 활동지역이 같거나 인접한 지역\n'
                        '- 그룹 인원 수가 같음\n'
                        '- 매칭 대기 중인 상태',
                  ),
                  _buildFAQItem(
                    question: '프로필 사진은 몇 장까지 등록할 수 있나요?',
                    answer: '최대 6장까지 등록할 수 있습니다.\n'
                        '1번째 사진이 메인 프로필 사진으로 사용되며, 나머지는 추가 사진으로 표시됩니다.',
                  ),
                  _buildFAQItem(
                    question: '그룹에서 나가고 싶어요.',
                    answer: '홈 화면 우상단 메뉴에서 "그룹 나가기"를 선택하세요.\n'
                        '그룹을 나간 후에는 다시 초대를 받거나 새 그룹을 만들어야 합니다.',
                  ),
                  _buildFAQItem(
                    question: '매칭이 안 되는 이유가 뭔가요?',
                    answer: '다음 경우에 매칭이 어려울 수 있습니다:\n'
                        '- 같은 활동지역에 매칭 대기 중인 그룹이 없는 경우\n'
                        '- 같은 인원 수의 그룹이 없는 경우\n'
                        '- 매칭 시간대에 활성 사용자가 적은 경우',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 이용 가이드 섹션
            _buildSectionCard(
              title: '이용 가이드',
              icon: Icons.book_outlined,
              child: Column(
                children: [
                  _buildGuideItem(
                    icon: Icons.person_add,
                    title: '회원가입',
                    description: '기본 정보 입력 후 프로필을 완성하세요',
                    onTap: () => _showGuideDetail(
                      context,
                      '회원가입 가이드',
                      '1. 아이디, 비밀번호, 전화번호, 생년월일, 성별을 입력하세요\n'
                      '2. 프로필 사진을 업로드하세요 (최대 6장)\n'
                      '3. 키, 닉네임, 활동지역, 소개글을 작성하세요\n'
                      '4. 프로필 완성 후 매칭을 시작할 수 있습니다',
                    ),
                  ),
                  _buildGuideItem(
                    icon: Icons.group_add,
                    title: '그룹 만들기',
                    description: '친구들을 초대해서 그룹을 구성하세요',
                    onTap: () => _showGuideDetail(
                      context,
                      '그룹 만들기 가이드',
                      '1. 홈 화면에서 "그룹 만들기" 버튼을 누르세요\n'
                      '2. "친구 초대하기"를 통해 친구들을 초대하세요\n'
                      '3. 친구들이 초대를 수락하면 그룹이 구성됩니다\n'
                      '4. 최대 5명까지 그룹을 구성할 수 있습니다',
                    ),
                  ),
                  _buildGuideItem(
                    icon: Icons.favorite,
                    title: '매칭하기',
                    description: '1:1 또는 그룹 매칭을 시작하세요',
                    onTap: () => _showGuideDetail(
                      context,
                      '매칭하기 가이드',
                      '1. 그룹이 구성되면 "매칭 시작" 버튼이 활성화됩니다\n'
                      '2. 혼자인 경우 "1:1 매칭 시작"을 선택하세요\n'
                      '3. 그룹인 경우 "그룹 매칭 시작"을 선택하세요\n'
                      '4. 매칭이 완료되면 알림이 오고 채팅을 시작할 수 있습니다',
                    ),
                  ),
                  _buildGuideItem(
                    icon: Icons.chat,
                    title: '채팅하기',
                    description: '매칭된 상대방과 채팅을 나누세요',
                    onTap: () => _showGuideDetail(
                      context,
                      '채팅하기 가이드',
                      '1. 매칭이 완료되면 "채팅하기" 버튼이 나타납니다\n'
                      '2. 채팅방에서 상대방과 대화를 나누세요\n'
                      '3. 서로를 알아가는 시간을 가져보세요\n'
                      '4. 실제 만남을 계획해보세요',
                    ),
                  ),
                  _buildGuideItem(
                    icon: Icons.security,
                    title: '안전하게 이용하기',
                    description: '안전한 만남을 위한 주의사항을 확인하세요',
                    onTap: () => _showGuideDetail(
                      context,
                      '안전 이용 가이드',
                      '🔒 개인정보 보호\n'
                      '- 개인정보(주소, 직장 등)는 충분히 신뢰할 때까지 공개하지 마세요\n\n'
                      '👥 첫 만남\n'
                      '- 첫 만남은 공공장소에서 진행하세요\n'
                      '- 친구들과 함께 만나는 것을 권장합니다\n\n'
                      '🚨 신고하기\n'
                      '- 부적절한 행동을 하는 사용자는 즉시 신고해주세요\n'
                      '- 불쾌한 메시지나 사진을 받으면 스크린샷을 남기고 신고하세요',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 문의하기 섹션
            _buildSectionCard(
              title: '문의하기',
              icon: Icons.contact_support_outlined,
              child: Column(
                children: [
                  _buildContactItem(
                    icon: Icons.email_outlined,
                    title: '이메일 문의',
                    subtitle: 'support@groupting.com',
                    onTap: () => _sendEmail(),
                  ),
                  _buildContactItem(
                    icon: Icons.phone_outlined,
                    title: '전화 문의',
                    subtitle: '1588-0000 (평일 09:00-18:00)',
                    onTap: () => _makePhoneCall(),
                  ),
                  _buildContactItem(
                    icon: Icons.chat_bubble_outline,
                    title: '카카오톡 문의',
                    subtitle: '@groupting',
                    onTap: () => _openKakaoTalk(),
                  ),
                  _buildContactItem(
                    icon: Icons.bug_report_outlined,
                    title: '버그 신고',
                    subtitle: '앱 사용 중 문제가 발생했나요?',
                    onTap: () => _showBugReportDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 운영시간 및 정책 섹션
            _buildSectionCard(
              title: '서비스 정보',
              icon: Icons.info_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '고객센터 운영시간',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '평일: 09:00 - 18:00\n주말 및 공휴일: 휴무',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '응답시간',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '이메일: 24시간 이내\n전화: 즉시 연결\n카카오톡: 운영시간 내 즉시',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideItem({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        description,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondary,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondary,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  void _showGuideDetail(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@groupting.com',
      query: 'subject=그룹팅 앱 문의&body=문의 내용을 작성해 주세요.',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw 'Could not launch email';
      }
    } catch (e) {
      // print('이메일 실행 실패: $e');
      // 이메일 앱이 없는 경우 클립보드에 복사
    }
  }

  Future<void> _makePhoneCall() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '1588-0000');

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw 'Could not launch phone';
      }
    } catch (e) {
      // print('전화 실행 실패: $e');
    }
  }

  Future<void> _openKakaoTalk() async {
    // 카카오톡 채널 링크 (실제 서비스에서는 실제 링크 사용이 필요. 현재 링크는 가볍게 테스트 작성용)
    final Uri kakaoUri = Uri.parse('https://pf.kakao.com/_groupting');

    try {
      if (await canLaunchUrl(kakaoUri)) {
        await launchUrl(kakaoUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch KakaoTalk';
      }
    } catch (e) {
      // print('카카오톡 실행 실패: $e');
    }
  }

  void _showBugReportDialog(BuildContext context) {
    final bugReportController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('버그 신고'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('발견한 버그나 문제점을 자세히 설명해 주세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: bugReportController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '버그 내용, 발생 상황, 기기 정보 등을 포함해 주세요...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('버그 신고가 접수되었습니다. 빠른 시일 내에 확인하겠습니다.'),
                ),
              );
            },
            child: const Text('신고하기'),
          ),
        ],
      ),
    );
  }
} 