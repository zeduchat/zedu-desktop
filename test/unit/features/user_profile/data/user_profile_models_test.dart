import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('ProfileAccountModel', () {
    test('retains saved fields from a backend profile summary', () {
      final account = ProfileAccountModel.fromJson(const {
        'full_name': 'Test Learner',
        'email': 'learner@example.com',
        'timezone': 'Africa/Lagos',
        'display_name': 'Learner',
        'username': 'test-learner',
        'phone': '+2348000000000',
        'title': 'Student',
        'name_pronounciation': 'lear-ner',
      });

      expect(account.name, 'Test Learner');
      expect(account.displayName, 'Learner');
      expect(account.username, 'test-learner');
      expect(account.phoneNumber, '+2348000000000');
      expect(account.title, 'Student');
      expect(account.namePronunciation, 'lear-ner');
      expect(account.country, isEmpty);
    });

    test('preserves legacy account fields through serialization', () {
      const json = {
        'name': 'Test Learner',
        'email': 'learner@example.com',
        'timezone': 'Africa/Lagos',
        'avatar_url': 'https://example.com/avatar.png',
        'display_name': 'Learner',
        'username': 'test-learner',
        'phone_number': '+2348000000000',
        'title': 'Student',
        'name_pronunciation': 'lear-ner',
        'country': 'Nigeria',
      };

      expect(ProfileAccountModel.fromJson(json).toJson(), json);
    });

    test('uses defaults when optional profile values are absent or null', () {
      final account = ProfileAccountModel.fromJson(const {
        'full_name': null,
        'phone': null,
        'name_pronounciation': null,
      });

      expect(account.name, 'Anonymous user');
      expect(account.displayName, isEmpty);
      expect(account.username, isEmpty);
      expect(account.phoneNumber, isEmpty);
      expect(account.title, isEmpty);
      expect(account.namePronunciation, isEmpty);
      expect(account.country, isEmpty);
    });

    test('maps account json to entity fields', () {
      final account = ProfileAccountModel.fromJson(const {
        'name': 'Anonymous user',
        'email': 'anonymoususer@email.com',
        'timezone': 'Africa/Lagos',
        'avatar_url': 'https://example.com/avatar.png',
      });

      expect(account.name, 'Anonymous user');
      expect(account.email, 'anonymoususer@email.com');
      expect(account.timezone, 'Africa/Lagos');
      expect(account.initials, 'AU');
      expect(account.avatarUrl, 'https://example.com/avatar.png');
    });
  });

  group('OrganizationProfileModel', () {
    test('reads the organisation endpoint name, type and country', () {
      final organization = OrganizationProfileModel.fromJson(const {
        'id': 'org-1',
        'name': 'HNG Internship',
        'type': 'Education',
        'country': 'Nigeria',
      });

      expect(organization.name, 'HNG Internship');
      expect(organization.natureOfBusiness, 'Education');
      expect(organization.country, 'Nigeria');
    });

    test('does not invent demo values for missing fields', () {
      final organization = OrganizationProfileModel.fromJson(const {});

      expect(organization.name, isEmpty);
      expect(organization.natureOfBusiness, isEmpty);
      expect(organization.country, isEmpty);
    });
  });

  group('NotificationPreferencesModel', () {
    Map<String, dynamic> device({
      String notifyAbout = 'all_new_messages',
      bool sendMail = false,
      String timeRange = '12:00 AM - 11:59 PM',
    }) => {
      'notify_about': notifyAbout,
      'send_mail': sendMail,
      'time_range': timeRange,
    };

    test('maps mode and email from the device preferences', () {
      final preferences = NotificationPreferencesModel.fromDeviceJson(
        device(notifyAbout: 'mentions', sendMail: true),
        timezone: 'Africa/Lagos',
      );

      expect(preferences.mode, NotificationMode.mentionsOnly);
      expect(preferences.emailNotifications, isTrue);
      expect(preferences.timezone, 'Africa/Lagos');
    });

    test('treats an all-day delivery window as quiet hours off', () {
      final preferences = NotificationPreferencesModel.fromDeviceJson(device());

      expect(preferences.quietHoursEnabled, isFalse);
      expect(preferences.timezone, isNull);
    });

    test('reads the delivery window as quiet hours across midnight', () {
      final preferences = NotificationPreferencesModel.fromDeviceJson(
        device(timeRange: '07:00 AM - 09:59 PM'),
      );

      expect(preferences.quietHoursEnabled, isTrue);
      expect(preferences.pauseFrom, 22 * 60);
      expect(preferences.resumeAt, 7 * 60);
      expect(preferences.quietHoursCrossMidnight, isTrue);
    });

    test('writes quiet hours back as the delivery window', () {
      final json = NotificationPreferencesModel.toDeviceJson(
        NotificationPreferences.empty().copyWith(
          mode: NotificationMode.none,
          quietHoursEnabled: true,
          pauseFrom: 22 * 60,
          resumeAt: 7 * 60,
        ),
        deviceType: 'desktop',
      );

      expect(json, {
        'notify_about': 'nothing',
        'send_mail': false,
        'time_range': '7:00 AM - 9:59 PM',
        'device_type': 'desktop',
      });
    });

    test('round-trips quiet hours that start at midnight', () {
      final saved = NotificationPreferences.empty().copyWith(
        quietHoursEnabled: true,
        pauseFrom: 0,
        resumeAt: 6 * 60,
      );
      final json = NotificationPreferencesModel.toDeviceJson(
        saved,
        deviceType: 'desktop',
      );

      expect(json['time_range'], '6:00 AM - 11:59 PM');
      expect(NotificationPreferencesModel.fromDeviceJson(json), saved);
    });

    test('sends the all-day window when quiet hours are off', () {
      final json = NotificationPreferencesModel.toDeviceJson(
        NotificationPreferences.empty(),
        deviceType: 'mobile',
      );

      expect(json['time_range'], NotificationPreferencesModel.allDay);
      expect(json['device_type'], 'mobile');
    });

    test('mobile shares the settings when they match', () {
      final preferences = NotificationPreferencesModel.fromDeviceJson(
        device(timeRange: '7:00 AM - 9:59 PM'),
        mobile: device(timeRange: '07:00 AM - 09:59 PM'),
      );

      expect(preferences.differentMobileSettings, isFalse);
    });

    test('mobile has its own settings when they differ', () {
      final preferences = NotificationPreferencesModel.fromDeviceJson(
        device(),
        mobile: device(notifyAbout: 'nothing'),
      );

      expect(preferences.differentMobileSettings, isTrue);
    });
  });

  group('NotificationPreferences', () {
    test('ignores the times while quiet hours are off', () {
      final saved = NotificationPreferences.empty();
      final edited = saved.copyWith(pauseFrom: 60, resumeAt: 120);

      expect(edited, saved);
      expect(edited.hashCode, saved.hashCode);
      expect(edited.copyWith(quietHoursEnabled: true), isNot(saved));
    });

    test('formats and parses times of day', () {
      expect(formatMinutesOfDay(0), '12:00 AM');
      expect(formatMinutesOfDay(12 * 60 + 5), '12:05 PM');
      expect(formatMinutesOfDay(-1), '11:59 PM');
      expect(parseMinutesOfDay('12:00 AM'), 0);
      expect(parseMinutesOfDay('09:30 PM'), 21 * 60 + 30);
      expect(parseMinutesOfDay('18:15'), 18 * 60 + 15);
      expect(parseMinutesOfDay('13:00 PM'), isNull);
      expect(parseMinutesOfDay('noon'), isNull);
    });
  });

  group('TeamMemberModel', () {
    test('maps pending members from json', () {
      final member = TeamMemberModel.fromJson(const {
        'id': 'member-2',
        'email': 'invitee@zedu.chat',
        'role': 'Manager',
        'date_joined': 'Pending',
        'status': 'pending',
      });

      expect(member.id, 'member-2');
      expect(member.email, 'invitee@zedu.chat');
      expect(member.role, 'Manager');
      expect(member.status, TeamMemberStatus.pending);
    });
  });
}
