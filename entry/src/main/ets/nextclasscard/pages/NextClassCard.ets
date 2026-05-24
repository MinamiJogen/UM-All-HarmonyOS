const local = new LocalStorage();

@Entry(local)
@Component
struct NextClassCard {
  @LocalStorageProp('hasCourse') hasCourse: string = '0';
  @LocalStorageProp('title') title: string = '下节课';
  @LocalStorageProp('courseCode') courseCode: string = '暂无课程';
  @LocalStorageProp('timeText') timeText: string = '--:--';
  @LocalStorageProp('locationText') locationText: string = '地点未定';

  readonly ACTION_TYPE: string = 'router';
  readonly BUNDLE_NAME: string = 'com.shuyuan.umarkall';
  readonly MODULE_NAME: string = 'entry';
  readonly ABILITY_NAME: string = 'EntryAbility';
  readonly FULL_SIZE: string = '100%';

  private hasUpcomingClass(): boolean {
    return this.hasCourse === '1';
  }

  private surfaceColor(): string {
    return this.hasUpcomingClass() ? '#EAF4FF' : '#F3F4F6';
  }

  private accentColor(): string {
    return this.hasUpcomingClass() ? '#0969DA' : '#6B7280';
  }

  private openTimetable(): void {
    postCardAction(this, {
      action: this.ACTION_TYPE,
      bundleName: this.BUNDLE_NAME,
      moduleName: this.MODULE_NAME,
      abilityName: this.ABILITY_NAME,
      params: {
        target: 'timetable'
      }
    });
  }

  @Builder
  TimeLine(): void {
    Row({ space: 6 }) {
      Text('时间')
        .fontSize(11)
        .fontColor('#6B7280')
        .width(30)
        .maxLines(1)
      Text(this.timeText)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111827')
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(this.FULL_SIZE)
  }

  @Builder
  LocationLine(): void {
    Row({ space: 6 }) {
      Text('地点')
        .fontSize(11)
        .fontColor('#6B7280')
        .width(30)
        .maxLines(1)
      Text(this.locationText)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111827')
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(this.FULL_SIZE)
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.title)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .layoutWeight(1)
        Text('UMARKALL')
          .fontSize(10)
          .fontColor(this.accentColor())
          .maxLines(1)
      }
      .width(this.FULL_SIZE)

      Text(this.courseCode)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.accentColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(this.FULL_SIZE)

      Column({ space: 5 }) {
        this.TimeLine()
        this.LocationLine()
      }
      .width(this.FULL_SIZE)
    }
    .width(this.FULL_SIZE)
    .height(this.FULL_SIZE)
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.surfaceColor())
    .onClick(() => {
      this.openTimetable();
    })
  }
}
